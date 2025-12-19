import Foundation
import Combine

// Simple SignalR client for real-time updates
// Note: For production, consider using the official SignalR Swift client package

class SignalRService: ObservableObject {
    @Published var isConnected = false
    @Published var lastFeedingLog: FeedingLog?
    @Published var lastCatUpdate: Cat?
    @Published var lastMessage: HouseholdMessage?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var token: String?
    private var householdId: String?
    
    func connect(token: String, householdId: String) {
        self.token = token
        self.householdId = householdId
        
        guard let url = URL(string: "\(APIConfig.hubURL)?access_token=\(token)") else {
            print("Invalid SignalR URL")
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnected = true
        
        // Send join household message
        let joinMessage = """
        {"type":1,"target":"JoinHousehold","arguments":["\(householdId)"]}
        """
        send(message: joinMessage)
        
        receiveMessages()
    }
    
    func disconnect() {
        if let householdId = householdId {
            let leaveMessage = """
            {"type":1,"target":"LeaveHousehold","arguments":["\(householdId)"]}
            """
            send(message: leaveMessage)
        }
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    private func send(message: String) {
        let message = URLSessionWebSocketTask.Message.string(message + "\u{1e}")
        webSocketTask?.send(message) { error in
            if let error = error {
                print("SignalR send error: \(error)")
            }
        }
    }
    
    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                
                // Continue receiving
                self?.receiveMessages()
                
            case .failure(let error):
                print("SignalR receive error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        // SignalR messages are separated by record separator
        let messages = text.split(separator: "\u{1e}")
        
        for msg in messages {
            guard let data = msg.data(using: .utf8) else { continue }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? Int {
                    
                    if type == 1, // Invocation
                       let target = json["target"] as? String,
                       let arguments = json["arguments"] as? [Any] {
                        
                        handleInvocation(target: target, arguments: arguments)
                    }
                }
            } catch {
                print("Failed to parse SignalR message: \(error)")
            }
        }
    }
    
    private func handleInvocation(target: String, arguments: [Any]) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        DispatchQueue.main.async { [weak self] in
            switch target {
            case "FeedingLogAdded":
                if let argData = try? JSONSerialization.data(withJSONObject: arguments[0]),
                   let log = try? decoder.decode(FeedingLog.self, from: argData) {
                    self?.lastFeedingLog = log
                }
                
            case "CatUpdated", "CatAdded":
                if let argData = try? JSONSerialization.data(withJSONObject: arguments[0]),
                   let cat = try? decoder.decode(Cat.self, from: argData) {
                    self?.lastCatUpdate = cat
                }
                
            case "MessageAdded":
                if let argData = try? JSONSerialization.data(withJSONObject: arguments[0]),
                   let message = try? decoder.decode(HouseholdMessage.self, from: argData) {
                    self?.lastMessage = message
                }
                
            default:
                print("Unhandled SignalR target: \(target)")
            }
        }
    }
}
