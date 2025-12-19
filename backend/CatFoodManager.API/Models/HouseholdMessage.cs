using System.Text.Json.Serialization;

namespace CatFoodManager.API.Models;

public class HouseholdMessage
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("partitionKey")]
    public string PartitionKey { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type => "message";

    [JsonPropertyName("householdId")]
    public string HouseholdId { get; set; } = string.Empty;

    [JsonPropertyName("fromUserId")]
    public string FromUserId { get; set; } = string.Empty;

    [JsonPropertyName("fromUserName")]
    public string FromUserName { get; set; } = string.Empty;

    [JsonPropertyName("content")]
    public string Content { get; set; } = string.Empty;

    [JsonPropertyName("isAdminMessage")]
    public bool IsAdminMessage { get; set; }

    [JsonPropertyName("isPinned")]
    public bool IsPinned { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
