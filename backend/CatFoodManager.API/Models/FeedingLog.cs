using System.Text.Json.Serialization;

namespace CatFoodManager.API.Models;

public class FeedingLog
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("partitionKey")]
    public string PartitionKey { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type => "feedingLog";

    [JsonPropertyName("householdId")]
    public string HouseholdId { get; set; } = string.Empty;

    [JsonPropertyName("catId")]
    public string CatId { get; set; } = string.Empty;

    [JsonPropertyName("catName")]
    public string CatName { get; set; } = string.Empty;

    [JsonPropertyName("fedByUserId")]
    public string FedByUserId { get; set; } = string.Empty;

    [JsonPropertyName("fedByUserName")]
    public string FedByUserName { get; set; } = string.Empty;

    [JsonPropertyName("fedAt")]
    public DateTime FedAt { get; set; } = DateTime.UtcNow;

    [JsonPropertyName("portionSize")]
    public string PortionSize { get; set; } = string.Empty;

    [JsonPropertyName("foodType")]
    public string FoodType { get; set; } = string.Empty;

    [JsonPropertyName("notes")]
    public string? Notes { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
