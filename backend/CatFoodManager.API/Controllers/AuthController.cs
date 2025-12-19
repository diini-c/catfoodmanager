using Microsoft.AspNetCore.Mvc;
using CatFoodManager.API.DTOs;
using CatFoodManager.API.Models;
using CatFoodManager.API.Services;
using User = CatFoodManager.API.Models.User;

namespace CatFoodManager.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly ICosmosDbService _cosmosDb;
    private readonly ITokenService _tokenService;

    public AuthController(ICosmosDbService cosmosDb, ITokenService tokenService)
    {
        _cosmosDb = cosmosDb;
        _tokenService = tokenService;
    }

    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register([FromBody] RegisterRequest request)
    {
        // Check if email already exists
        var existingUser = await _cosmosDb.GetUserByEmailAsync(request.Email);
        if (existingUser != null)
        {
            return BadRequest(new { message = "Email already registered" });
        }

        // Create new user
        var user = new User
        {
            Email = request.Email,
            DisplayName = request.DisplayName,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password)
        };

        await _cosmosDb.CreateUserAsync(user);

        var token = _tokenService.GenerateToken(user);
        return Ok(new AuthResponse(
            token,
            new UserDto(user.Id, user.Email, user.DisplayName, user.HouseholdId, user.Role.ToString())
        ));
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login([FromBody] LoginRequest request)
    {
        var user = await _cosmosDb.GetUserByEmailAsync(request.Email);
        if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            return Unauthorized(new { message = "Invalid email or password" });
        }

        // Update last login
        user.LastLoginAt = DateTime.UtcNow;
        await _cosmosDb.UpdateUserAsync(user);

        var token = _tokenService.GenerateToken(user);
        return Ok(new AuthResponse(
            token,
            new UserDto(user.Id, user.Email, user.DisplayName, user.HouseholdId, user.Role.ToString())
        ));
    }
}
