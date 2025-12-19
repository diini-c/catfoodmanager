using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using CatFoodManager.API.DTOs;
using CatFoodManager.API.Hubs;
using CatFoodManager.API.Models;
using CatFoodManager.API.Services;

namespace CatFoodManager.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FeedingLogsController : ControllerBase
{
    private readonly ICosmosDbService _cosmosDb;
    private readonly IHubContext<FeedingHub, IFeedingHubClient> _hubContext;

    public FeedingLogsController(ICosmosDbService cosmosDb, IHubContext<FeedingHub, IFeedingHubClient> hubContext)
    {
        _cosmosDb = cosmosDb;
        _hubContext = hubContext;
    }

    private string GetUserId() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value!;
    private string GetUserName() => User.FindFirst(ClaimTypes.Name)?.Value ?? "Unknown";

    private async Task<(User? user, string? householdId, ActionResult? error)> ValidateUserHousehold()
    {
        var userId = GetUserId();
        var user = await _cosmosDb.GetUserByIdAsync(userId);
        if (user == null) return (null, null, NotFound());

        if (user.HouseholdId == null)
        {
            return (user, null, BadRequest(new { message = "You are not in a household" }));
        }

        return (user, user.HouseholdId, null);
    }

    [HttpGet]
    public async Task<ActionResult<List<FeedingLogDto>>> GetFeedingLogs([FromQuery] int limit = 50)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        var logs = await _cosmosDb.GetFeedingLogsByHouseholdAsync(householdId!, limit);
        return Ok(logs.Select(l => new FeedingLogDto(
            l.Id, l.CatId, l.CatName, l.FedByUserId, l.FedByUserName, l.FedAt, l.PortionSize, l.FoodType, l.Notes
        )).ToList());
    }

    [HttpGet("cat/{catId}")]
    public async Task<ActionResult<List<FeedingLogDto>>> GetFeedingLogsByCat(string catId, [FromQuery] int limit = 20)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        var logs = await _cosmosDb.GetFeedingLogsByCatAsync(householdId!, catId, limit);
        return Ok(logs.Select(l => new FeedingLogDto(
            l.Id, l.CatId, l.CatName, l.FedByUserId, l.FedByUserName, l.FedAt, l.PortionSize, l.FoodType, l.Notes
        )).ToList());
    }

    [HttpPost]
    public async Task<ActionResult<FeedingLogDto>> CreateFeedingLog([FromBody] CreateFeedingLogRequest request)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        var cat = await _cosmosDb.GetCatByIdAsync(householdId!, request.CatId);
        if (cat == null) return NotFound(new { message = "Cat not found" });

        var log = new FeedingLog
        {
            HouseholdId = householdId!,
            CatId = cat.Id,
            CatName = cat.Name,
            FedByUserId = GetUserId(),
            FedByUserName = user!.DisplayName,
            PortionSize = request.PortionSize ?? cat.FeedingSchedule.PortionSize,
            FoodType = request.FoodType ?? cat.FeedingSchedule.FoodType,
            Notes = request.Notes
        };

        await _cosmosDb.CreateFeedingLogAsync(log);

        var logDto = new FeedingLogDto(
            log.Id, log.CatId, log.CatName, log.FedByUserId, log.FedByUserName, log.FedAt, log.PortionSize, log.FoodType, log.Notes
        );

        // Broadcast to all household members in real-time
        await _hubContext.Clients.Group($"household_{householdId}").FeedingLogAdded(logDto);

        return Ok(logDto);
    }
}
