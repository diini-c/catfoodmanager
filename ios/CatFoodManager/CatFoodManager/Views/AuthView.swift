import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Logo and title
                VStack(spacing: 8) {
                    Image(systemName: "cat.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Cat Food Manager")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Keep track of your cats' meals")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Mode picker
                Picker("Mode", selection: $isLoginMode) {
                    Text("Login").tag(true)
                    Text("Sign Up").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Form fields
                VStack(spacing: 16) {
                    if !isLoginMode {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocapitalization(.words)
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isLoginMode ? .password : .newPassword)
                }
                .padding(.horizontal)
                
                // Error message
                if let error = authManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Submit button
                Button(action: submit) {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isLoginMode ? "Login" : "Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(authManager.isLoading || !isFormValid)
                .opacity(isFormValid ? 1 : 0.6)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
    
    private var isFormValid: Bool {
        if isLoginMode {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty && !displayName.isEmpty
        }
    }
    
    private func submit() {
        Task {
            if isLoginMode {
                await authManager.login(email: email, password: password)
            } else {
                await authManager.register(email: email, password: password, displayName: displayName)
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
