using System.Text.Json.Serialization;

namespace CatFoodManager.API.Models;

public class Cat
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("partitionKey")]
    public string PartitionKey { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type => "cat";

    [JsonPropertyName("householdId")]
    public string HouseholdId { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("breed")]
    public string? Breed { get; set; }

    [JsonPropertyName("birthDate")]
    public DateTime? BirthDate { get; set; }

    [JsonPropertyName("weight")]
    public double? Weight { get; set; }

    [JsonPropertyName("photoUrl")]
    public string? PhotoUrl { get; set; }

    [JsonPropertyName("notes")]
    public string? Notes { get; set; }

    [JsonPropertyName("feedingSchedule")]
    public FeedingSchedule FeedingSchedule { get; set; } = new();

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [JsonPropertyName("updatedAt")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class FeedingSchedule
{
    [JsonPropertyName("timesPerDay")]
    public int TimesPerDay { get; set; } = 2;

    [JsonPropertyName("scheduledTimes")]
    public List<string> ScheduledTimes { get; set; } = new() { "08:00", "18:00" };

    [JsonPropertyName("portionSize")]
    public string PortionSize { get; set; } = "1/4 cup";

    [JsonPropertyName("foodType")]
    public string FoodType { get; set; } = "Dry food";

    [JsonPropertyName("specialInstructions")]
    public string? SpecialInstructions { get; set; }
}
