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
public class HouseholdController : ControllerBase
{
    private readonly ICosmosDbService _cosmosDb;
    private readonly IHubContext<FeedingHub, IFeedingHubClient> _hubContext;
    private readonly ITokenService _tokenService;

    public HouseholdController(ICosmosDbService cosmosDb, IHubContext<FeedingHub, IFeedingHubClient> hubContext, ITokenService tokenService)
    {
        _cosmosDb = cosmosDb;
        _hubContext = hubContext;
        _tokenService = tokenService;
    }

    private string GetUserId() => User.FindFirst(ClaimTypes.NameIdentifier)?.Value!;

    [HttpPost]
    public async Task<ActionResult<HouseholdDto>> CreateHousehold([FromBody] CreateHouseholdRequest request)
    {
        var userId = GetUserId();
        var user = await _cosmosDb.GetUserByIdAsync(userId);
        if (user == null) return NotFound();

        if (user.HouseholdId != null)
        {
            return BadRequest(new { message = "You are already in a household" });
        }

        var household = new Household
        {
            Name = request.Name,
            AdminUserId = userId
        };

        await _cosmosDb.CreateHouseholdAsync(household);

        // Update user with household and admin role
        user.HouseholdId = household.Id;
        user.Role = UserRole.Admin;
        await _cosmosDb.UpdateUserAsync(user);

        var members = new List<UserDto> 
        { 
            new(user.Id, user.Email, user.DisplayName, user.HouseholdId, user.Role.ToString()) 
        };

        return Ok(new HouseholdDto(household.Id, household.Name, household.InviteCode, household.AdminUserId, members));
    }

    [HttpPost("join")]
    public async Task<ActionResult<HouseholdDto>> JoinHousehold([FromBody] JoinHouseholdRequest request)
    {
        var userId = GetUserId();
        var user = await _cosmosDb.GetUserByIdAsync(userId);
        if (user == null) return NotFound();

        if (user.HouseholdId != null)
        {
            return BadRequest(new { message = "You are already in a household" });
        }

        var household = await _cosmosDb.GetHouseholdByInviteCodeAsync(request.InviteCode);
        if (household == null)
        {
            return NotFound(new { message = "Invalid invite code" });
        }

        // Add user to household
        user.HouseholdId = household.Id;
        user.Role = UserRole.Member;
        await _cosmosDb.UpdateUserAsync(user);

        // Notify other members
        await _hubContext.Clients.Group($"household_{household.Id}")
            .MemberJoined(new UserDto(user.Id, user.Email, user.DisplayName, user.HouseholdId, user.Role.ToString()));

        var members = await _cosmosDb.GetUsersByHouseholdAsync(household.Id);
        var memberDtos = members.Select(m => new UserDto(m.Id, m.Email, m.DisplayName, m.HouseholdId, m.Role.ToString())).ToList();

        return Ok(new HouseholdDto(household.Id, household.Name, household.InviteCode, household.AdminUserId, memberDtos));
    }

    [HttpGet]
    public async Task<ActionResult<HouseholdDto>> GetHousehold()
    {
        var userId = GetUserId();
        var user = await _cosmosDb.GetUserByIdAsync(userId);
        if (user == null) return NotFound();

        if (user.HouseholdId == null)
        {
            return NotFound(new { message = "You are not in a household" });
        }

        var household = await _cosmosDb.GetHouseholdByIdAsync(user.HouseholdId);
        if (household == null) return NotFound();

        var members = await _cosmosDb.GetUsersByHouseholdAsync(household.Id);
        var memberDtos = members.Select(m => new UserDto(m.Id, m.Email, m.DisplayName, m.HouseholdId, m.Role.ToString())).ToList();

        return Ok(new HouseholdDto(household.Id, household.Name, household.InviteCode, household.AdminUserId, memberDtos));
    }

    [HttpPost("leave")]
    public async Task<ActionResult> LeaveHousehold()
    {
        var userId = GetUserId();
        var user = await _cosmosDb.GetUserByIdAsync(userId);
        if (user == null) return NotFound();

        if (user.HouseholdId == null)
        {
            return BadRequest(new { message = "You are not in a household" });
        }

        var household = await _cosmosDb.GetHouseholdByIdAsync(user.HouseholdId);
        if (household == null) return NotFound();

        if (household.AdminUserId == userId)
        {
            return BadRequest(new { message = "Admin cannot leave. Transfer admin role first or delete the household." });
        }

        var householdId = user.HouseholdId;
        user.HouseholdId = null;
        user.Role = UserRole.Member;
        await _cosmosDb.UpdateUserAsync(user);

        await _hubContext.Clients.Group($"household_{householdId}")
            .MemberLeft(userId);

        return Ok(new { message = "Successfully left household" });
    }

    [HttpPost("members/{memberId}/role")]
    public async Task<ActionResult> UpdateMemberRole(string memberId, [FromBody] UpdateMemberRoleRequest request)
    {
        var userId = GetUserId();
        var user = await _cosmosDb.GetUserByIdAsync(userId);
        if (user == null) return NotFound();

        if (user.HouseholdId == null)
        {
            return BadRequest(new { message = "You are not in a household" });
        }

        var household = await _cosmosDb.GetHouseholdByIdAsync(user.HouseholdId);
        if (household == null) return NotFound();

        if (household.AdminUserId != userId)
        {
            return Forbid();
        }

        var member = await _cosmosDb.GetUserByIdAsync(memberId);
        if (member == null || member.HouseholdId != household.Id)
        {
            return NotFound(new { message = "Member not found" });
        }

        if (Enum.TryParse<UserRole>(request.Role, true, out var newRole))
        {
            member.Role = newRole;
            await _cosmosDb.UpdateUserAsync(member);

            // If transferring admin, update household and current user
            if (newRole == UserRole.Admin && memberId != userId)
            {
                household.AdminUserId = memberId;
                await _cosmosDb.UpdateHouseholdAsync(household);

                user.Role = UserRole.Member;
                await _cosmosDb.UpdateUserAsync(user);
            }

            await _hubContext.Clients.Group($"household_{household.Id}")
                .MemberRoleChanged(memberId, newRole.ToString());
        }

        return Ok(new { message = "Role updated" });
    }

    [HttpPost("regenerate-invite")]
    public async Task<ActionResult<string>> RegenerateInviteCode()
    {
        var userId = GetUserId();
        var user = await _cosmosDb.GetUserByIdAsync(userId);
        if (user == null) return NotFound();

        if (user.HouseholdId == null || user.Role != UserRole.Admin)
        {
            return Forbid();
        }

        var household = await _cosmosDb.GetHouseholdByIdAsync(user.HouseholdId);
        if (household == null) return NotFound();

        // Generate new invite code
        const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var random = new Random();
        household.InviteCode = new string(Enumerable.Repeat(chars, 6)
            .Select(s => s[random.Next(s.Length)]).ToArray());

        await _cosmosDb.UpdateHouseholdAsync(household);

        return Ok(new { inviteCode = household.InviteCode });
    }

    [HttpGet("new-token")]
    public async Task<ActionResult<string>> GetNewToken()
    {
        var userId = GetUserId();
        var user = await _cosmosDb.GetUserByIdAsync(userId);
        if (user == null) return NotFound();

        var token = _tokenService.GenerateToken(user);
        return Ok(new { token });
    }
}
