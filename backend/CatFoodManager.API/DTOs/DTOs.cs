namespace CatFoodManager.API.DTOs;

// Auth DTOs
public record RegisterRequest(string Email, string Password, string DisplayName);
public record LoginRequest(string Email, string Password);
public record AuthResponse(string Token, UserDto User);
public record UserDto(string Id, string Email, string DisplayName, string? HouseholdId, string Role);

// Household DTOs
public record CreateHouseholdRequest(string Name);
public record JoinHouseholdRequest(string InviteCode);
public record HouseholdDto(string Id, string Name, string InviteCode, string AdminUserId, List<UserDto> Members);
public record UpdateMemberRoleRequest(string UserId, string Role);

// Cat DTOs
public record CreateCatRequest(string Name, string? Breed, DateTime? BirthDate, double? Weight, string? Notes);
public record UpdateCatRequest(string Name, string? Breed, DateTime? BirthDate, double? Weight, string? Notes);
public record UpdateFeedingScheduleRequest(int TimesPerDay, List<string> ScheduledTimes, string PortionSize, string FoodType, string? SpecialInstructions);
public record CatDto(string Id, string Name, string? Breed, DateTime? BirthDate, double? Weight, string? PhotoUrl, string? Notes, FeedingScheduleDto FeedingSchedule);
public record FeedingScheduleDto(int TimesPerDay, List<string> ScheduledTimes, string PortionSize, string FoodType, string? SpecialInstructions);

// Feeding Log DTOs
public record CreateFeedingLogRequest(string CatId, string? PortionSize, string? FoodType, string? Notes);
public record FeedingLogDto(string Id, string CatId, string CatName, string FedByUserId, string FedByUserName, DateTime FedAt, string PortionSize, string FoodType, string? Notes);

// Message DTOs
public record CreateMessageRequest(string Content, bool IsPinned);
public record MessageDto(string Id, string FromUserId, string FromUserName, string Content, bool IsAdminMessage, bool IsPinned, DateTime CreatedAt);
