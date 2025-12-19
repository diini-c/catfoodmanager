import Foundation
import Combine

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var token: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let tokenKey = "auth_token"
    private let userKey = "auth_user"
    
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    func checkStoredToken() {
        if let token = UserDefaults.standard.string(forKey: tokenKey),
           let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? decoder.decode(User.self, from: userData) {
            self.token = token
            self.user = user
            self.isAuthenticated = true
        }
    }
    
    func register(email: String, password: String, displayName: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            let request = RegisterRequest(email: email, password: password, displayName: displayName)
            let response: AuthResponse = try await APIClient.shared.post(
                endpoint: "/auth/register",
                body: request
            )
            
            await MainActor.run {
                saveAuth(token: response.token, user: response.user)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func login(email: String, password: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            let request = LoginRequest(email: email, password: password)
            let response: AuthResponse = try await APIClient.shared.post(
                endpoint: "/auth/login",
                body: request
            )
            
            await MainActor.run {
                saveAuth(token: response.token, user: response.user)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        token = nil
        user = nil
        isAuthenticated = false
    }
    
    func refreshUser() async {
        guard let currentToken = token else { return }
        
        do {
            let response: [String: String] = try await APIClient.shared.get(
                endpoint: "/household/new-token",
                token: currentToken
            )
            
            if let newToken = response["token"] {
                // Decode the new token to get updated user info
                // For simplicity, we'll fetch the household which includes user info
                await MainActor.run {
                    self.token = newToken
                    UserDefaults.standard.set(newToken, forKey: tokenKey)
                }
            }
        } catch {
            print("Failed to refresh token: \(error)")
        }
    }
    
    func updateUser(_ newUser: User) {
        user = newUser
        if let userData = try? encoder.encode(newUser) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
    }
    
    private func saveAuth(token: String, user: User) {
        self.token = token
        self.user = user
        self.isAuthenticated = true
        
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let userData = try? encoder.encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
    }
}
