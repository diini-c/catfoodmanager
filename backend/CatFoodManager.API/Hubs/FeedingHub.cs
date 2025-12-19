using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using CatFoodManager.API.DTOs;

namespace CatFoodManager.API.Hubs;

[Authorize]
public class FeedingHub : Hub
{
    public async Task JoinHousehold(string householdId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"household_{householdId}");
    }

    public async Task LeaveHousehold(string householdId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"household_{householdId}");
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        await base.OnDisconnectedAsync(exception);
    }
}

public interface IFeedingHubClient
{
    Task FeedingLogAdded(FeedingLogDto log);
    Task CatUpdated(CatDto cat);
    Task CatAdded(CatDto cat);
    Task CatDeleted(string catId);
    Task MessageAdded(MessageDto message);
    Task MessageDeleted(string messageId);
    Task MemberJoined(UserDto user);
    Task MemberLeft(string userId);
    Task MemberRoleChanged(string userId, string newRole);
}
