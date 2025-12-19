import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if authManager.user?.householdId != nil {
                    MainTabView()
                } else {
                    HouseholdSetupView()
                }
            } else {
                AuthView()
            }
        }
        .onAppear {
            authManager.checkStoredToken()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
