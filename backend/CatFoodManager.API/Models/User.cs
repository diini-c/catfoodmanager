using System.Text.Json.Serialization;

namespace CatFoodManager.API.Models;

public class User
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("partitionKey")]
    public string PartitionKey => "user";

    [JsonPropertyName("type")]
    public string Type => "user";

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("passwordHash")]
    public string PasswordHash { get; set; } = string.Empty;

    [JsonPropertyName("displayName")]
    public string DisplayName { get; set; } = string.Empty;

    [JsonPropertyName("householdId")]
    public string? HouseholdId { get; set; }

    [JsonPropertyName("role")]
    public UserRole Role { get; set; } = UserRole.Member;

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [JsonPropertyName("lastLoginAt")]
    public DateTime? LastLoginAt { get; set; }
}

public enum UserRole
{
    Member = 0,
    Admin = 1
}
