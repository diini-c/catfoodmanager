# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A family cat-feeding tracker: a native SwiftUI iOS app talking to a .NET 8 Web API, with real-time
sync via SignalR and data stored in a single Cosmos DB container. Everything is designed to run on
free Azure tiers (App Service F1 + Cosmos DB free tier). There are two code trees that must be kept
in sync by hand — `backend/` (API contract + SignalR events) and `ios/` (client models + API calls) —
there is no shared schema/codegen between them.

## Commands

### Backend (`backend/CatFoodManager.API`)

```bash
cd backend/CatFoodManager.API
dotnet run                 # runs at https://localhost:5001 (http://localhost:5000)
dotnet build
dotnet publish -c Release
```

There is no test project and no linter configured for the backend. Local development requires either
the Azure Cosmos DB Emulator or a real Cosmos DB connection string in `appsettings.Development.json`
(`CosmosDb:AccountEndpoint`, `CosmosDb:AccountKey`) plus a `Jwt:Secret` (32+ chars).

### iOS (`ios/CatFoodManager`)

Open `ios/CatFoodManager/CatFoodManager.xcodeproj` in Xcode and run on simulator/device. There is no
CLI build/test flow set up (no `xcodebuild` scheme docs, no XCTest targets). Before running against a
local backend, change `APIConfig.baseURL` in `ios/CatFoodManager/CatFoodManager/Models/Models.swift`
to `http://localhost:5000`; for a deployed backend it points at the Azure App Service URL.

### Deploy (`azure/`)

`azure/deploy.ps1` (PowerShell) provisions the ARM template (`azuredeploy.json`) and publishes the API
to Azure App Service. See `README.md` for the manual `az` CLI equivalent.

## Architecture

### Single-container Cosmos DB model

All entities (`user`, `household`, `cat`, `feedingLog`, `message`) live in **one Cosmos container**,
distinguished by a `type` discriminator field and partitioned by a `partitionKey` string:
- Users: partition `"user"`.
- Everything else (household, cats, feeding logs, messages): partition `"household_{householdId}"`.

All access goes through `Services/CosmosDbService.cs` (`ICosmosDbService`), which hand-writes every
query (`SELECT * FROM c WHERE c.type = '...' AND ...`). There is no ORM — when adding a new entity
type, add it to this service (interface + implementation) rather than introducing a new access
pattern, and set `PartitionKey` consistently with the existing `household_{id}` convention so queries
stay single-partition.

### Request flow and real-time fan-out

Controllers in `Controllers/` are thin: resolve the caller's household via
`ValidateUserHousehold()` (reads the JWT `NameIdentifier` claim → looks up the `User` → requires
`user.HouseholdId`), authorize by `user.Role` (only `UserRole.Admin` can mutate cats/schedules),
call `ICosmosDbService`, map to a DTO (`DTOs/DTOs.cs`), and then **push the same DTO out over
SignalR** via `IHubContext<FeedingHub, IFeedingHubClient>` to the group `household_{householdId}`.
Every mutating endpoint follows this three-step pattern (persist → map to DTO → broadcast), so a new
mutation needs a matching event added to `IFeedingHubClient` (`Hubs/FeedingHub.cs`) and a matching
`@objc`/Combine handler added to `SignalRService` on the iOS side.

Auth is JWT bearer (`Services/TokenService.cs`), issued by `AuthController`. The same JWT is reused as
a SignalR access token: `Program.cs` pulls it from the `access_token` query string specifically for
requests under `/hubs`.

### iOS client structure

- `Managers/AppState.swift` is the single `ObservableObject` source of truth: it loads all household
  data on login, and subscribes to `SignalRService`'s published properties (`$lastFeedingLog`,
  `$lastCatUpdate`, `$lastMessage`) to merge live updates into its own `@Published` arrays
  (update-in-place if the id already exists, else insert/append).
- `Services/APIClient.swift` is a minimal generic REST client (get/post/put/delete) — no retry/caching
  layer, each call passes the bearer token explicitly.
- `Services/SignalRService.swift` owns the SignalR hub connection lifecycle, joined/left in step with
  `AppState.loadData` / `clearData`.
- Backend DTOs and iOS `Models.swift` are maintained by hand in parallel; when changing a DTO shape in
  `DTOs/DTOs.cs`, update the corresponding Swift `Codable` struct in the same change.

### Authorization model

Single `UserRole` enum (`Admin`/`Member`) per household, checked ad hoc in each controller action
(no policy/attribute-based authorization) — grep for `user!.Role != UserRole.Admin` when auditing or
extending permission checks. Households are joined via a 6-character invite code generated at
creation and looked up via a cross-partition query (`GetHouseholdByInviteCodeAsync`).
