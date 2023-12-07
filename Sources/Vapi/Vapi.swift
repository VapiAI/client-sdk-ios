import Foundation
import Daily

// MARK: - Constants

let VAPI_API_URL = "https://api.vapi.ai/call/web"

// MARK: - Models

struct WebCallResponse: Decodable {
    let webCallUrl: String
}

struct WebCallRequestBody {
    let assistantId: String?
    let assistant: [String: Any]?
}

enum VapiError: Swift.Error {
    case invalidURL
    case networkError(Swift.Error)
    case decodingError(Swift.Error)
    case encodingError(Swift.Error)
    case customError(String)
}

// MARK: - Delegate Protocol

protocol VapiDelegate: AnyObject {
    func callDidStart()
    func callDidEnd()
    func didEncounterError(error: VapiError)
}

// MARK: - Network Manager

class NetworkManager {
    static func performRequest<T: Decodable>(urlRequest: URLRequest, completion: @escaping (Result<T, VapiError>) -> Void) {
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                guard let data = data else {
                    completion(.failure(.customError("No data received")))
                    return
                }
                do {
                    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decodedResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }.resume()
    }
}

// MARK: - Vapi Class

public class Vapi: CallClientDelegate {
    private let clientToken: String
    private let apiUrl: String

    weak var delegate: VapiDelegate?
    private var call: CallClient?

    public init(clientToken: String) {
        self.clientToken = clientToken
        self.apiUrl = VAPI_API_URL
    }
    
    public init(clientToken: String, apiUrl: String) {
        self.clientToken = clientToken
        self.apiUrl = apiUrl
    }

    @MainActor
    private func joinCall(with url: URL) {
        Task {
            do {
                let call = CallClient()
                _ = try await call.join(url: url, settings: CallClientSettings.defaultSettings())
                
                self.call = call
                self.call?.delegate = self
                self.callDidJoin()
            } catch {
                self.delegate?.didEncounterError(error: .networkError(error))
            }
        }
    }

    @MainActor
    private func startCall(body: WebCallRequestBody) {
        guard let url = URL(string: self.apiUrl) else {
            self.delegate?.didEncounterError(error: .invalidURL)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(self.clientToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.delegate?.didEncounterError(error: .encodingError(error))
            return
        }

        NetworkManager.performRequest(urlRequest: request) { (result: Result<WebCallResponse, VapiError>) in
            switch result {
                case .success(let response):
                    if let url = URL(string: response.webCallUrl) {
                        DispatchQueue.main.async {
                            self.joinCall(with: url)
                        }
                    } else {
                        self.delegate?.didEncounterError(error: .customError("Invalid webCallUrl"))
                    }
                case .failure(let error):
                    self.delegate?.didEncounterError(error: error)
            }
        }
    }

    // MARK: - Public Interface

    @MainActor
    public func start(assistantId: String) {
        let body = WebCallRequestBody(assistantId: assistantId, assistant: nil)
        self.startCall(body: body)
    }

    @MainActor
    public func start(assistant: [String: Any]) {
        let body = WebCallRequestBody(assistantId: nil, assistant: assistant)
        self.startCall(body: body)
    }

    public func stop() {
        Task {
            do {
                try await call?.leave()
                self.callDidLeave()
            } catch {
                self.delegate?.didEncounterError(error: .networkError(error))
            }
        }
    }

    // MARK: - CallClientDelegate Methods

    func callDidJoin() {
        print("Successfully joined call.")
        self.delegate?.callDidStart()
    }

    func callDidLeave() {
        print("Successfully left call.")
        self.delegate?.callDidEnd()
    }

    func callDidFail(with error: Error) {
        print("Got error while joining/leaving call: \(error).")
        self.delegate?.didEncounterError(error: .networkError(error))
    }

    // participantUpdated event
    func callClient(_ callClient: CallClient, participantUpdated participant: Participant) {
        print("Participant Updated: \(participant)")
    }

    // participantJoined event
    func callClient(_ callClient: CallClient, participantJoined participant: Participant) {
        print("Participant Joined: \(participant)")
        if participant.info.username == "Vapi Speaker" {
            let message: [String: Any] = ["message": "playable"]
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
                Task.detached {
                    try await self.call?.sendAppMessage(json: jsonData, to: .all)
                }
            } catch {
                print("Error sending message: \(error.localizedDescription)")
            }
        }
    }

    // subscriptionProfilesUpdated event
    func callClient(_ callClient: CallClient, subscriptionProfilesUpdated subscriptionProfiles: SubscriptionProfileSettingsByProfile) {
        print("Subscription Profiles Updated: \(subscriptionProfiles)")
    }

    // subscriptionsUpdated event
    func callClient(_ callClient: CallClient, subscriptionsUpdated subscriptions: SubscriptionSettingsByID) {
        print("Subscriptions Updated: \(subscriptions)")
    }
}

// MARK: - Helper Classes/Structs

// Assuming CallClient, Participant, and other related types are defined elsewhere

struct CallClientSettings {
    static func defaultSettings() -> CallClient.Settings {
        // Return default settings
        // This is a placeholder. You should implement this according to your application's needs.
        return CallClient.Settings()
    }
}

// Participant model (Placeholder - Define according to actual requirements)
struct Participant {
    var info: ParticipantInfo
}

// ParticipantInfo model (Placeholder - Define according to actual requirements)
struct ParticipantInfo {
    var username: String
}

// SubscriptionProfileSettingsByProfile and SubscriptionSettingsByID (Placeholder - Define according to actual requirements)
struct SubscriptionProfileSettingsByProfile { /* ... */ }
struct SubscriptionSettingsByID { /* ... */ }

// CallClient (Placeholder - Define according to actual requirements)
class CallClient {
    func join(url: URL, settings: CallClient.Settings) async throws { /* ... */ }
    func leave() async throws { /* ... */ }
    func sendAppMessage(json: Data, to: AppMessageRecipient) async throws { /* ... */ }
    var delegate: CallClientDelegate?
    
    struct Settings { /* ... */ }
}

// CallClientDelegate (Placeholder - Define according to actual requirements)
protocol CallClientDelegate {
    func callClient(_ callClient: CallClient, participantUpdated participant: Participant)
    func callClient(_ callClient: CallClient, participantJoined participant: Participant)
    func callClient(_ callClient: CallClient, subscriptionProfilesUpdated subscriptionProfiles: SubscriptionProfileSettingsByProfile)
    func callClient(_ callClient: CallClient, subscriptionsUpdated subscriptions: SubscriptionSettingsByID)
}

enum AppMessageRecipient {
    case all
    // Define other cases as needed
}

// MARK: - End of Vapi Class
