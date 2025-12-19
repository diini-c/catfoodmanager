# 🐱 Cat Food Manager

A family iOS app for tracking cat feeding schedules with real-time sync across all family devices.

## Features

- 👨‍👩‍👧‍👦 **Family Households** - Create a household and invite family members with a simple 6-character code
- 🐱 **Multiple Cats** - Manage feeding schedules for all your cats
- 📝 **Feeding Logs** - Track who fed which cat and when, synced in real-time
- 👑 **Admin Controls** - Household admin can manage cats, schedules, and member permissions
- 💬 **Family Messages** - Share notes and pin important announcements
- ⚡ **Real-time Sync** - SignalR-powered instant updates across all family devices

## Architecture

```
┌─────────────────┐     ┌──────────────────────────────────┐
│   iOS App       │────▶│  Azure App Service (Free Tier)   │
│   (SwiftUI)     │◀────│  .NET 8 Web API + SignalR Hub    │
└─────────────────┘     └──────────────────────────────────┘
                                        │
                                        ▼
                        ┌──────────────────────────────────┐
                        │   Azure Cosmos DB (Free Tier)    │
                        │   1000 RU/s, 25GB storage        │
                        └──────────────────────────────────┘
```

## Cost: $0/month

This project uses **100% FREE Azure tiers**:
- **App Service F1**: Free tier (60 CPU minutes/day)
- **Cosmos DB**: Free tier (1000 RU/s, 25GB)
- **SignalR**: Built into App Service (no separate service needed)

## Quick Start

### 1. Deploy Backend to Azure

```powershell
# Navigate to azure folder
cd azure

# Run deployment script
.\deploy.ps1 -ResourceGroupName "catfood-rg" -Location "eastus" -AppName "mycatfood" -JwtSecret "YOUR_VERY_LONG_SECRET_KEY_AT_LEAST_32_CHARS"
```

Or deploy manually:

```powershell
# Create resource group
az group create --name catfood-rg --location eastus

# Deploy ARM template
az deployment group create --resource-group catfood-rg --template-file azuredeploy.json --parameters appName=mycatfood jwtSecret=YOUR_SECRET_KEY

# Build and deploy backend
cd ../backend/CatFoodManager.API
dotnet publish -c Release
az webapp deploy --resource-group catfood-rg --name mycatfood-api --src-path bin/Release/net8.0/publish
```

### 2. Configure iOS App

Update the API URL in `ios/CatFoodManager/CatFoodManager/Models/Models.swift`:

```swift
struct APIConfig {
    static let baseURL = "https://mycatfood-api.azurewebsites.net"
    // ...
}
```

### 3. Install on Family iPhones (No Apple Developer Account!)

See [iOS Sideloading Guide](#ios-sideloading-without-apple-developer-account) below.

---

## iOS Sideloading Without Apple Developer Account

Since you don't have an Apple Developer account ($99/year), here are your FREE options to install the app on family devices:

### Option 1: Direct Xcode Install (Recommended for Development)

**Requirements:**
- Mac with Xcode installed
- Each family member's iPhone connected via USB
- Free Apple ID for each device

**Steps:**

1. Open `ios/CatFoodManager/CatFoodManager.xcodeproj` in Xcode

2. In Xcode, go to **Xcode → Preferences → Accounts** and add your Apple ID

3. Select the project in the navigator, go to **Signing & Capabilities**:
   - Check "Automatically manage signing"
   - Select your Personal Team (free Apple ID)
   - Change the Bundle Identifier to something unique: `com.yourname.catfoodmanager`

4. Connect each family iPhone via USB

5. Select the connected device in the device dropdown

6. Click **Run** (▶️) to build and install

**⚠️ Important Limitations:**
- Apps expire after **7 days** - you must reinstall weekly
- Max **3 apps** per device with free Apple ID
- Device must be connected to Mac to reinstall

### Option 2: AltStore (Best for Family Distribution)

AltStore lets you install apps and auto-refreshes them before they expire!

**On YOUR Mac (once):**

1. Download [AltServer for Mac](https://altstore.io/)
2. Install AltServer and keep it running
3. Enable "Mail plug-in" when prompted (for signing)

**On EACH family iPhone:**

1. Connect iPhone to Mac running AltServer
2. Open AltServer menu → Install AltStore → Select device
3. Enter your Apple ID when prompted (can use same ID for all)
4. AltStore app appears on iPhone

**To Install Cat Food Manager:**

1. In Xcode, go to **Product → Archive**
2. Click **Distribute App → Ad Hoc → Export**
3. This creates a `.ipa` file
4. Transfer the `.ipa` to each iPhone (AirDrop, iCloud, etc.)
5. Open in AltStore on the iPhone to install

**Benefits:**
- AltStore auto-refreshes apps in background (with WiFi + AltServer running)
- Family members don't need a Mac after initial setup

### Option 3: Sideloadly (Windows/Mac)

If you're on Windows:

1. Download [Sideloadly](https://sideloadly.io/)
2. Export `.ipa` from Xcode (Archive → Distribute → Ad Hoc)
3. Connect iPhone to Windows PC
4. Open Sideloadly, select `.ipa` file
5. Enter your Apple ID
6. Click Start

**Same 7-day limitation applies**

### Refreshing Expired Apps

With free Apple ID, apps expire every 7 days. Options:

| Method | Effort | Automation |
|--------|--------|------------|
| Xcode reinstall | High - need Mac + USB | None |
| AltStore | Low - opens app periodically | Auto when on same WiFi as AltServer |
| Sideloadly | Medium | Manual every 7 days |

**Pro Tip:** Set a weekly reminder to refresh, or keep AltServer running on a Mac that's always on.

---

## Project Structure

```
catfoodmanager/
├── backend/
│   └── CatFoodManager.API/          # .NET 8 Web API
│       ├── Controllers/              # API endpoints
│       ├── Models/                   # Data models
│       ├── Services/                 # Cosmos DB service
│       ├── Hubs/                     # SignalR hub
│       └── DTOs/                     # Request/Response DTOs
├── ios/
│   └── CatFoodManager/               # SwiftUI iOS app
│       └── CatFoodManager/
│           ├── Views/                # SwiftUI views
│           ├── Models/               # Data models
│           ├── Managers/             # State management
│           └── Services/             # API client, SignalR
└── azure/
    ├── azuredeploy.json              # ARM template
    └── deploy.ps1                    # Deployment script
```

## API Endpoints

| Endpoint | Method | Description | Auth |
|----------|--------|-------------|------|
| `/api/auth/register` | POST | Register new user | No |
| `/api/auth/login` | POST | Login | No |
| `/api/household` | GET | Get current household | Yes |
| `/api/household` | POST | Create household | Yes |
| `/api/household/join` | POST | Join with invite code | Yes |
| `/api/cats` | GET | List all cats | Yes |
| `/api/cats` | POST | Add cat (admin only) | Yes |
| `/api/cats/{id}` | PUT | Update cat (admin only) | Yes |
| `/api/cats/{id}/schedule` | PUT | Update feeding schedule | Yes |
| `/api/feedinglogs` | GET | Get feeding history | Yes |
| `/api/feedinglogs` | POST | Log a feeding | Yes |
| `/api/messages` | GET | Get household messages | Yes |
| `/api/messages` | POST | Send message | Yes |

## SignalR Hub

Connect to `/hubs/feeding` with JWT token for real-time events:

- `FeedingLogAdded` - New feeding logged
- `CatUpdated` / `CatAdded` / `CatDeleted` - Cat changes
- `MessageAdded` / `MessageDeleted` - Message updates
- `MemberJoined` / `MemberLeft` - Household membership changes

## Local Development

### Backend

```powershell
# Install Cosmos DB Emulator or use Azure
# https://docs.microsoft.com/en-us/azure/cosmos-db/local-emulator

cd backend/CatFoodManager.API
dotnet run
```

API runs at `https://localhost:5001`

### iOS App

1. Open in Xcode
2. Update `APIConfig.baseURL` to `http://localhost:5000`
3. Run on Simulator

## Troubleshooting

### "Unable to install app" on iPhone
- Go to Settings → General → VPN & Device Management → Trust your developer profile

### SignalR not connecting
- Ensure WebSockets are enabled in Azure App Service
- Check that JWT token is being passed correctly

### Cosmos DB connection fails
- Verify connection string in App Service Configuration
- Check firewall rules if using local emulator

## License

MIT - Use freely for your family's cats! 🐱
