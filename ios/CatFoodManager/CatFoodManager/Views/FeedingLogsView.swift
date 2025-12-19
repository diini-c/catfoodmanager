import SwiftUI

struct FeedingLogsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @State private var selectedCatId: String?
    
    private var filteredLogs: [FeedingLog] {
        if let catId = selectedCatId {
            return appState.feedingLogs.filter { $0.catId == catId }
        }
        return appState.feedingLogs
    }
    
    private var groupedLogs: [(String, [FeedingLog])] {
        let grouped = Dictionary(grouping: filteredLogs) { log in
            formatDate(log.fedAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Cat filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedCatId == nil) {
                            selectedCatId = nil
                        }
                        
                        ForEach(appState.cats) { cat in
                            FilterChip(title: cat.name, isSelected: selectedCatId == cat.id) {
                                selectedCatId = cat.id
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGray6))
                
                if filteredLogs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No feeding logs yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Log a feeding from a cat's detail page")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedLogs, id: \.0) { date, logs in
                            Section(header: Text(date)) {
                                ForEach(logs) { log in
                                    FeedingLogRow(log: log)
                                }
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
            .navigationTitle("Feeding Log")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.orange : Color(.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct FeedingLogRow: View {
    let log: FeedingLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(log.catName)
                    .font(.headline)
                
                Spacer()
                
                Text(formatTime(log.fedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label(log.portionSize, systemImage: "scalemass")
                    .font(.caption)
                
                Spacer()
                
                Text(log.foodType)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "person.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Fed by \(log.fedByUserName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let notes = log.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    FeedingLogsView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
