import Foundation
import Daily

// MARK: - Constants

let VAPI_API_URL = "https://api.vapi.ai/call/web"

// MARK: - Models

struct WebCallResponse: Decodable {
    let webCallUrl: String
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
                self.call = call
                
                _ = try await call.join(
                    url: url,
                    settings: .init(
                        inputs: .set(
                            camera: .set(.enabled(false)),
                            microphone: .set(.enabled(true))
                        )
                    )
                )
                
                self.call?.delegate = self
            } catch {
                self.callDidFail(with: .networkError(error))
            }
        }
    }

    @MainActor
    private func startCall(body: [String: Any]) {
        guard let url = URL(string: self.apiUrl) else {
            self.delegate?.didEncounterError(error: .invalidURL)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(self.clientToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        print(body)
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
        if(self.call != nil) { return }
        let body = ["assistantId":assistantId]
        self.startCall(body: body)
    }

    @MainActor
    public func start(assistant: [String: Any]) {
        if(self.call != nil) { return }
        let body = ["assistant":assistant]
        self.startCall(body: body)
    }

    public func stop() {
        Task {
            do {
                try await call?.leave()
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
        self.call = nil
    }

    func callDidFail(with error: VapiError) {
        print("Got error while joining/leaving call: \(error).")
        self.delegate?.didEncounterError(error: .networkError(error))
        self.call = nil
    }

    // participantUpdated event
    public func callClient(_ callClient: CallClient, participantUpdated participant: Participant) {
        print("Participant Updated: \(participant)")
    }

    // participantJoined event
    public func callClient(_ callClient: CallClient, participantJoined participant: Participant) {
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
    public func callClient(_ callClient: CallClient, subscriptionProfilesUpdated subscriptionProfiles: SubscriptionProfileSettingsByProfile) {
        print("Subscription Profile Updated: \(subscriptionProfiles)")
    }

    // subscriptionsUpdated event
    public func callClient(_ callClient: CallClient, subscriptionsUpdated subscriptions: SubscriptionSettingsByID) {
        print("Subscription Updated: \(subscriptions)")
    }
    
 
    // callStateUpdated event
    public func callClient(
        _ callClient: CallClient,
        callStateUpdated state: CallState
    ) {
        switch(state){
        case CallState.left:
            self.callDidLeave()
            break
        case CallState.joined:
            self.callDidJoin()
            break
        default:
            break
        }
    }
}

// MARK: - End of Vapi Class
