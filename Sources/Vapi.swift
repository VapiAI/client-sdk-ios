import Combine
import Daily
import Foundation

/// A delegate that clients can adopt to be notified of API events.
public protocol VapiDelegate: AnyObject {
    func callDidStart()
    func callDidEnd()
    func didEncounterError(error: VapiError)
}

public final class Vapi {
    /// A configuration that contains the host URL and the client token.
    ///
    /// This configuration is serializable via `Codable`.
    public struct Configuration: Codable, Hashable, Sendable {
        public var host: URL
        public var clientToken: String
        
        init(host: URL = URL(string: "https://api.vapi.ai")!, clientToken: String) {
            self.host = host
            self.clientToken = clientToken
        }
    }
    
    public enum Event {
        case callDidStart
        case callDidEnd
        case error(VapiError)
    }
    
    fileprivate let eventSubject = PassthroughSubject<Event, Never>()
    
    /// A Combine publisher that clients can subscribe to for API events.
    public var eventPublisher: AnyPublisher<Event, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    public let configuration: Configuration
    
    private var apiUrl: String {
        configuration.host.absoluteString
    }
    
    private var clientToken: String {
        configuration.clientToken
    }
    
    public weak var delegate: VapiDelegate?
    
    private var call: CallClient?
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        
        Daily.setLogLevel(.error)
    }
    
    public convenience init(
        clientToken: String
    ) {
        self.init(configuration: .init(clientToken: clientToken))
    }
    
    public convenience init(
        clientToken: String,
        hostURL: URL
    ) {
        self.init(configuration: .init(host: hostURL, clientToken: clientToken))
    }
    
    public func start(
        assistantId: String
    ) {
        guard self.call == nil else {
            return
        }
        
        let body = ["assistantId": assistantId]
        
        self.startCall(body: body)
    }
    
    public func start(
        assistant: [String: Any]
    ) {
        guard self.call == nil else {
            return
        }
        
        let body = ["assistant": assistant]
        
        self.startCall(body: body)
    }
    
    public func stop() {
        Task {
            do {
                try await call?.leave()
            } catch {
                self.callDidFail(with: .networkError(error))
            }
        }
    }
}

extension Vapi {
    @MainActor
    private func joinCall(with url: URL) async throws {
        do {
            let call = CallClient()
            self.call = call
            
            self.call?.delegate = self
            
            _ = try await call.join(
                url: url,
                settings: .init(
                    inputs: .set(
                        camera: .set(.enabled(false)),
                        microphone: .set(.enabled(true))
                    )
                )
            )
        } catch {
            self.callDidFail(with: .networkError(error))
        }
    }
    
    private func startCall(body: [String: Any]) {
        guard let url = URL(string: self.apiUrl + "/call/web") else {
            self.callDidFail(with: .invalidURL)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(self.clientToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.callDidFail(with: .encodingError(error))
            
            return
        }
        
        NetworkManager.performRequest(urlRequest: request) { (result: Result<WebCallResponse, VapiError>) in
            switch result {
                case .success(let response):
                    Task { @MainActor in
                        if let url = URL(string: response.webCallUrl) {
                            try await self.joinCall(with: url)
                        } else {
                            self.callDidFail(with: .customError("Invalid webCallUrl"))
                        }
                    }
                case .failure(let error):
                    Task { @MainActor in
                        self.callDidFail(with: error)
                    }
            }
        }
    }
}

// MARK: - Conformances

extension Vapi: Daily.CallClientDelegate {
    func callDidJoin() {
        print("Successfully joined call.")
        
        self.delegate?.callDidStart()
        self.eventSubject.send(.callDidStart)
    }
    
    func callDidLeave() {
        print("Successfully left call.")
        
        self.delegate?.callDidEnd()
        self.eventSubject.send(.callDidEnd)
        self.call = nil
    }
    
    func callDidFail(with error: VapiError) {
        print("Got error while joining/leaving call: \(error).")
        
        self.delegate?.didEncounterError(error: .networkError(error))
        self.eventSubject.send(.error(error))
        self.call = nil
    }
    
    // participantUpdated event
    public func callClient(
        _ callClient: CallClient,
        participantUpdated participant: Participant
    ) {
        let isPlayable = participant.media?.microphone.state == Daily.MediaState.playable
        if participant.info.username == "Vapi Speaker" && isPlayable {
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
    
    // callStateUpdated event
    public func callClient(
        _ callClient: CallClient,
        callStateUpdated state: CallState
    ) {
        switch (state) {
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

// MARK: - Auxiliary

struct WebCallResponse: Decodable {
    let webCallUrl: String
}

public enum VapiError: Swift.Error {
    case invalidURL
    case networkError(Swift.Error)
    case decodingError(Swift.Error)
    case encodingError(Swift.Error)
    case customError(String)
}
