import Foundation

// MARK: - API Configuration
struct APIConfig {
    // Change this to your Azure App Service URL when deployed
    static let baseURL = "https://YOUR-APP-NAME.azurewebsites.net"
    // For local development with iOS simulator:
    // static let baseURL = "http://localhost:5000"
    
    static let apiURL = "\(baseURL)/api"
    static let hubURL = "\(baseURL)/hubs/feeding"
}

// MARK: - User
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    let householdId: String?
    let role: String
    
    var isAdmin: Bool {
        role.lowercased() == "admin"
    }
}

// MARK: - Auth
struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let displayName: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

// MARK: - Household
struct Household: Codable, Identifiable {
    let id: String
    let name: String
    let inviteCode: String
    let adminUserId: String
    let members: [User]
}

struct CreateHouseholdRequest: Codable {
    let name: String
}

struct JoinHouseholdRequest: Codable {
    let inviteCode: String
}

// MARK: - Cat
struct Cat: Codable, Identifiable {
    let id: String
    let name: String
    let breed: String?
    let birthDate: Date?
    let weight: Double?
    let photoUrl: String?
    let notes: String?
    let feedingSchedule: FeedingSchedule
}

struct FeedingSchedule: Codable {
    let timesPerDay: Int
    let scheduledTimes: [String]
    let portionSize: String
    let foodType: String
    let specialInstructions: String?
}

struct CreateCatRequest: Codable {
    let name: String
    let breed: String?
    let birthDate: Date?
    let weight: Double?
    let notes: String?
}

struct UpdateFeedingScheduleRequest: Codable {
    let timesPerDay: Int
    let scheduledTimes: [String]
    let portionSize: String
    let foodType: String
    let specialInstructions: String?
}

// MARK: - Feeding Log
struct FeedingLog: Codable, Identifiable {
    let id: String
    let catId: String
    let catName: String
    let fedByUserId: String
    let fedByUserName: String
    let fedAt: Date
    let portionSize: String
    let foodType: String
    let notes: String?
}

struct CreateFeedingLogRequest: Codable {
    let catId: String
    let portionSize: String?
    let foodType: String?
    let notes: String?
}

// MARK: - Message
struct HouseholdMessage: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let fromUserName: String
    let content: String
    let isAdminMessage: Bool
    let isPinned: Bool
    let createdAt: Date
}

struct CreateMessageRequest: Codable {
    let content: String
    let isPinned: Bool
}
