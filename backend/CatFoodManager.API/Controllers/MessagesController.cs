using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using CatFoodManager.API.DTOs;
using CatFoodManager.API.Hubs;
using CatFoodManager.API.Models;
using CatFoodManager.API.Services;
using User = CatFoodManager.API.Models.User;

namespace CatFoodManager.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MessagesController : ControllerBase
{
    private readonly ICosmosDbService _cosmosDb;
    private readonly IHubContext<FeedingHub, IFeedingHubClient> _hubContext;

    public MessagesController(ICosmosDbService cosmosDb, IHubContext<FeedingHub, IFeedingHubClient> hubContext)
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

    [HttpGet]
    public async Task<ActionResult<List<MessageDto>>> GetMessages([FromQuery] int limit = 50)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        var messages = await _cosmosDb.GetMessagesByHouseholdAsync(householdId!, limit);
        return Ok(messages.Select(m => new MessageDto(
            m.Id, m.FromUserId, m.FromUserName, m.Content, m.IsAdminMessage, m.IsPinned, m.CreatedAt
        )).ToList());
    }

    [HttpPost]
    public async Task<ActionResult<MessageDto>> CreateMessage([FromBody] CreateMessageRequest request)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        // Only admins can pin messages
        var isPinned = request.IsPinned && user!.Role == UserRole.Admin;

        var message = new HouseholdMessage
        {
            HouseholdId = householdId!,
            FromUserId = GetUserId(),
            FromUserName = user!.DisplayName,
            Content = request.Content,
            IsAdminMessage = user.Role == UserRole.Admin,
            IsPinned = isPinned
        };

        await _cosmosDb.CreateMessageAsync(message);

        var messageDto = new MessageDto(
            message.Id, message.FromUserId, message.FromUserName, message.Content, message.IsAdminMessage, message.IsPinned, message.CreatedAt
        );

        await _hubContext.Clients.Group($"household_{householdId}").MessageAdded(messageDto);

        return Ok(messageDto);
    }

    [HttpDelete("{messageId}")]
    public async Task<ActionResult> DeleteMessage(string messageId)
    {
        var (user, householdId, error) = await ValidateUserHousehold();
        if (error != null) return error;

        // Only admins can delete messages
        if (user!.Role != UserRole.Admin)
        {
            return Forbid();
        }

        await _cosmosDb.DeleteMessageAsync(householdId!, messageId);
        await _hubContext.Clients.Group($"household_{householdId}").MessageDeleted(messageId);

        return Ok(new { message = "Message deleted" });
    }
}
