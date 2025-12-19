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
public class CatsController : ControllerBase
{
    private readonly ICosmosDbService _cosmosDb;
    private readonly IHubContext<FeedingHub, IFeedingHubClient> _hubContext;

    public CatsController(ICosmosDbService cosmosDb, IHubContext<FeedingHub, IFeedingHubClient> hubContext)
    {
        _cosmosDb = cosmosDb;
        _hubContext = hubContext;
    }

    private string GetUserId() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value!;

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

    private CatDto MapToCatDto(Cat cat) => new(
        cat.Id,
        cat.Name,
        cat.Breed,
        cat.BirthDate,
        cat.Weight,
        cat.PhotoUrl,
        cat.Notes,
        new FeedingScheduleDto(
            cat.FeedingSchedule.TimesPerDay,
            cat.FeedingSchedule.ScheduledTimes,
            cat.FeedingSchedule.PortionSize,
            cat.FeedingSchedule.FoodType,
            cat.FeedingSchedule.SpecialInstructions
        )
    );

    [HttpGet]
    public async Task<ActionResult<List<CatDto>>> GetCats()
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        var cats = await _cosmosDb.GetCatsByHouseholdAsync(householdId!);
        return Ok(cats.Select(MapToCatDto).ToList());
    }

    [HttpGet("{catId}")]
    public async Task<ActionResult<CatDto>> GetCat(string catId)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        var cat = await _cosmosDb.GetCatByIdAsync(householdId!, catId);
        if (cat == null) return NotFound();

        return Ok(MapToCatDto(cat));
    }

    [HttpPost]
    public async Task<ActionResult<CatDto>> CreateCat([FromBody] CreateCatRequest request)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        // Only admins can add cats
        if (user!.Role != UserRole.Admin)
        {
            return Forbid();
        }

        var cat = new Cat
        {
            HouseholdId = householdId!,
            Name = request.Name,
            Breed = request.Breed,
            BirthDate = request.BirthDate,
            Weight = request.Weight,
            Notes = request.Notes
        };

        await _cosmosDb.CreateCatAsync(cat);

        var catDto = MapToCatDto(cat);
        await _hubContext.Clients.Group($"household_{householdId}").CatAdded(catDto);

        return Ok(catDto);
    }

    [HttpPut("{catId}")]
    public async Task<ActionResult<CatDto>> UpdateCat(string catId, [FromBody] UpdateCatRequest request)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        // Only admins can update cats
        if (user!.Role != UserRole.Admin)
        {
            return Forbid();
        }

        var cat = await _cosmosDb.GetCatByIdAsync(householdId!, catId);
        if (cat == null) return NotFound();

        cat.Name = request.Name;
        cat.Breed = request.Breed;
        cat.BirthDate = request.BirthDate;
        cat.Weight = request.Weight;
        cat.Notes = request.Notes;

        await _cosmosDb.UpdateCatAsync(cat);

        var catDto = MapToCatDto(cat);
        await _hubContext.Clients.Group($"household_{householdId}").CatUpdated(catDto);

        return Ok(catDto);
    }

    [HttpPut("{catId}/schedule")]
    public async Task<ActionResult<CatDto>> UpdateFeedingSchedule(string catId, [FromBody] UpdateFeedingScheduleRequest request)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        // Only admins can update feeding schedules
        if (user!.Role != UserRole.Admin)
        {
            return Forbid();
        }

        var cat = await _cosmosDb.GetCatByIdAsync(householdId!, catId);
        if (cat == null) return NotFound();

        cat.FeedingSchedule = new FeedingSchedule
        {
            TimesPerDay = request.TimesPerDay,
            ScheduledTimes = request.ScheduledTimes,
            PortionSize = request.PortionSize,
            FoodType = request.FoodType,
            SpecialInstructions = request.SpecialInstructions
        };

        await _cosmosDb.UpdateCatAsync(cat);

        var catDto = MapToCatDto(cat);
        await _hubContext.Clients.Group($"household_{householdId}").CatUpdated(catDto);

        return Ok(catDto);
    }

    [HttpDelete("{catId}")]
    public async Task<ActionResult> DeleteCat(string catId)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        // Only admins can delete cats
        if (user!.Role != UserRole.Admin)
        {
            return Forbid();
        }

        var cat = await _cosmosDb.GetCatByIdAsync(householdId!, catId);
        if (cat == null) return NotFound();

        await _cosmosDb.DeleteCatAsync(householdId!, catId);
        await _hubContext.Clients.Group($"household_{householdId}").CatDeleted(catId);

        return Ok(new { message = "Cat deleted" });
    }
}
