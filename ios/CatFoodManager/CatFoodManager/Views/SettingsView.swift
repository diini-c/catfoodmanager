import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @State private var showingInviteCode = false
    @State private var showingMembers = false
    
    var body: some View {
        NavigationView {
            List {
                // User section
                Section("Account") {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            Text(String(authManager.user?.displayName.prefix(1) ?? "?").uppercased())
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(authManager.user?.displayName ?? "Unknown")
                                .font(.headline)
                            
                            Text(authManager.user?.email ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if authManager.user?.isAdmin == true {
                            Text("Admin")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Household section
                Section("Household") {
                    HStack {
                        Label(appState.household?.name ?? "Unknown", systemImage: "house.fill")
                        Spacer()
                        Text("\(appState.household?.members.count ?? 0) members")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: { showingMembers = true }) {
                        Label("View Members", systemImage: "person.3.fill")
                    }
                    
                    if authManager.user?.isAdmin == true {
                        Button(action: { showingInviteCode = true }) {
                            Label("Invite Code", systemImage: "qrcode")
                        }
                    }
                }
                
                // Stats section
                Section("Stats") {
                    HStack {
                        Label("Cats", systemImage: "cat.fill")
                        Spacer()
                        Text("\(appState.cats.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Feedings Today", systemImage: "fork.knife")
                        Spacer()
                        Text("\(feedingsToday)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Connection status
                Section("Connection") {
                    HStack {
                        Label("Real-time Sync", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        if appState.signalR.isConnected {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("Disconnected", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                // Logout
                Section {
                    Button(role: .destructive) {
                        logout()
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingInviteCode) {
                InviteCodeView()
            }
            .sheet(isPresented: $showingMembers) {
                MembersView()
            }
        }
    }
    
    private var feedingsToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return appState.feedingLogs.filter { calendar.isDate($0.fedAt, inSameDayAs: today) }.count
    }
    
    private func logout() {
        appState.clearData()
        authManager.logout()
    }
}

struct InviteCodeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Invite Family Members")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Share this code with your family members so they can join your household")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text(appState.household?.inviteCode ?? "------")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                Button(action: copyCode) {
                    Label("Copy Code", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func copyCode() {
        UIPasteboard.general.string = appState.household?.inviteCode
    }
}

struct MembersView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(appState.household?.members ?? []) { member in
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Text(String(member.displayName.prefix(1)).uppercased())
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(member.displayName)
                                .font(.headline)
                            
                            Text(member.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if member.isAdmin {
                            Text("Admin")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
