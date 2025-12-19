import SwiftUI

struct HouseholdSetupView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    
    @State private var selectedTab = 0
    @State private var householdName = ""
    @State private var inviteCode = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Set Up Your Household")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Create a new household or join an existing one")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Picker("", selection: $selectedTab) {
                    Text("Create New").tag(0)
                    Text("Join Existing").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if selectedTab == 0 {
                    // Create household
                    VStack(spacing: 16) {
                        TextField("Household Name", text: $householdName)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("You'll be the admin of this household and can invite family members.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                } else {
                    // Join household
                    VStack(spacing: 16) {
                        TextField("Invite Code", text: $inviteCode)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.allCharacters)
                        
                        Text("Enter the 6-character invite code from your family's admin.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                if let error = appState.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: submit) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(selectedTab == 0 ? "Create Household" : "Join Household")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(isLoading || !isFormValid)
                .opacity(isFormValid ? 1 : 0.6)
                
                Spacer()
                
                Button("Logout") {
                    authManager.logout()
                }
                .foregroundColor(.red)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
    }
    
    private var isFormValid: Bool {
        if selectedTab == 0 {
            return !householdName.isEmpty
        } else {
            return inviteCode.count == 6
        }
    }
    
    private func submit() {
        guard let token = authManager.token else { return }
        isLoading = true
        
        Task {
            var success = false
            
            if selectedTab == 0 {
                success = await appState.createHousehold(name: householdName, token: token)
            } else {
                success = await appState.joinHousehold(inviteCode: inviteCode.uppercased(), token: token)
            }
            
            if success {
                await authManager.refreshUser()
                // Update user with household ID
                if let household = appState.household, var user = authManager.user {
                    let updatedUser = User(
                        id: user.id,
                        email: user.email,
                        displayName: user.displayName,
                        householdId: household.id,
                        role: selectedTab == 0 ? "Admin" : "Member"
                    )
                    authManager.updateUser(updatedUser)
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    HouseholdSetupView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
