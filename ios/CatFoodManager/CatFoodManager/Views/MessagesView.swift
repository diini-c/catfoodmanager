import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @State private var showingCompose = false
    
    private var pinnedMessages: [HouseholdMessage] {
        appState.messages.filter { $0.isPinned }
    }
    
    private var regularMessages: [HouseholdMessage] {
        appState.messages.filter { !$0.isPinned }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if appState.messages.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "message")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No messages yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Share notes with your family members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        if !pinnedMessages.isEmpty {
                            Section("📌 Pinned") {
                                ForEach(pinnedMessages) { message in
                                    MessageRow(message: message)
                                }
                            }
                        }
                        
                        Section("Recent") {
                            ForEach(regularMessages) { message in
                                MessageRow(message: message)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        if let token = authManager.token {
                            await appState.loadData(token: token)
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                Button(action: { showingCompose = true }) {
                    Image(systemName: "square.and.pencil")
                }
            }
            .sheet(isPresented: $showingCompose) {
                ComposeMessageView()
            }
        }
    }
}

struct MessageRow: View {
    let message: HouseholdMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if message.isAdminMessage {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Text(message.fromUserName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(formatDate(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(message.content)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ComposeMessageView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var content = ""
    @State private var isPinned = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextEditor(text: $content)
                        .frame(height: 150)
                }
                
                if authManager.user?.isAdmin == true {
                    Section {
                        Toggle("Pin this message", isOn: $isPinned)
                    } footer: {
                        Text("Pinned messages appear at the top for all family members")
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        sendMessage()
                    }
                    .disabled(content.isEmpty || isLoading)
                }
            }
        }
    }
    
    private func sendMessage() {
        guard let token = authManager.token else { return }
        isLoading = true
        
        let request = CreateMessageRequest(content: content, isPinned: isPinned)
        
        Task {
            let success = await appState.sendMessage(request, token: token)
            if success {
                dismiss()
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    MessagesView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
