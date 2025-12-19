import Foundation
import Combine

class AppState: ObservableObject {
    @Published var household: Household?
    @Published var cats: [Cat] = []
    @Published var feedingLogs: [FeedingLog] = []
    @Published var messages: [HouseholdMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let signalR = SignalRService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSignalRSubscriptions()
    }
    
    private func setupSignalRSubscriptions() {
        signalR.$lastFeedingLog
            .compactMap { $0 }
            .sink { [weak self] log in
                if let index = self?.feedingLogs.firstIndex(where: { $0.id == log.id }) {
                    self?.feedingLogs[index] = log
                } else {
                    self?.feedingLogs.insert(log, at: 0)
                }
            }
            .store(in: &cancellables)
        
        signalR.$lastCatUpdate
            .compactMap { $0 }
            .sink { [weak self] cat in
                if let index = self?.cats.firstIndex(where: { $0.id == cat.id }) {
                    self?.cats[index] = cat
                } else {
                    self?.cats.append(cat)
                }
            }
            .store(in: &cancellables)
        
        signalR.$lastMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                if let index = self?.messages.firstIndex(where: { $0.id == message.id }) {
                    self?.messages[index] = message
                } else {
                    self?.messages.insert(message, at: 0)
                }
            }
            .store(in: &cancellables)
    }
    
    func loadData(token: String) async {
        await MainActor.run { isLoading = true }
        
        do {
            async let householdTask: Household = APIClient.shared.get(endpoint: "/household", token: token)
            async let catsTask: [Cat] = APIClient.shared.get(endpoint: "/cats", token: token)
            async let logsTask: [FeedingLog] = APIClient.shared.get(endpoint: "/feedinglogs", token: token)
            async let messagesTask: [HouseholdMessage] = APIClient.shared.get(endpoint: "/messages", token: token)
            
            let (household, cats, logs, messages) = try await (householdTask, catsTask, logsTask, messagesTask)
            
            await MainActor.run {
                self.household = household
                self.cats = cats
                self.feedingLogs = logs
                self.messages = messages
                self.isLoading = false
                
                // Connect SignalR
                self.signalR.connect(token: token, householdId: household.id)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func createHousehold(name: String, token: String) async -> Bool {
        do {
            let request = CreateHouseholdRequest(name: name)
            let household: Household = try await APIClient.shared.post(
                endpoint: "/household",
                body: request,
                token: token
            )
            
            await MainActor.run {
                self.household = household
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    func joinHousehold(inviteCode: String, token: String) async -> Bool {
        do {
            let request = JoinHouseholdRequest(inviteCode: inviteCode)
            let household: Household = try await APIClient.shared.post(
                endpoint: "/household/join",
                body: request,
                token: token
            )
            
            await MainActor.run {
                self.household = household
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    func addCat(_ request: CreateCatRequest, token: String) async -> Bool {
        do {
            let cat: Cat = try await APIClient.shared.post(
                endpoint: "/cats",
                body: request,
                token: token
            )
            
            await MainActor.run {
                self.cats.append(cat)
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    func updateFeedingSchedule(catId: String, schedule: UpdateFeedingScheduleRequest, token: String) async -> Bool {
        do {
            let cat: Cat = try await APIClient.shared.put(
                endpoint: "/cats/\(catId)/schedule",
                body: schedule,
                token: token
            )
            
            await MainActor.run {
                if let index = self.cats.firstIndex(where: { $0.id == catId }) {
                    self.cats[index] = cat
                }
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    func logFeeding(_ request: CreateFeedingLogRequest, token: String) async -> Bool {
        do {
            let log: FeedingLog = try await APIClient.shared.post(
                endpoint: "/feedinglogs",
                body: request,
                token: token
            )
            
            await MainActor.run {
                self.feedingLogs.insert(log, at: 0)
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    func sendMessage(_ request: CreateMessageRequest, token: String) async -> Bool {
        do {
            let message: HouseholdMessage = try await APIClient.shared.post(
                endpoint: "/messages",
                body: request,
                token: token
            )
            
            await MainActor.run {
                self.messages.insert(message, at: 0)
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    func clearData() {
        signalR.disconnect()
        household = nil
        cats = []
        feedingLogs = []
        messages = []
    }
}
