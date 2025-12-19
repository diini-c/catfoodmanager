import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            CatsView()
                .tabItem {
                    Label("Cats", systemImage: "cat.fill")
                }
            
            FeedingLogsView()
                .tabItem {
                    Label("Feed Log", systemImage: "list.bullet.clipboard")
                }
            
            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .accentColor(.orange)
        .onAppear {
            if let token = authManager.token {
                Task {
                    await appState.loadData(token: token)
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
