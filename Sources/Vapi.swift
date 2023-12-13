import Combine
import Daily
import Foundation

public final class Vapi: CallClientDelegate {
    
    // MARK: - Supporting Types
    
    /// A configuration that contains the host URL and the client token.
    ///
    /// This configuration is serializable via `Codable`.
    public struct Configuration: Codable, Hashable, Sendable {
        public var host: String
        public var clientToken: String
        fileprivate static let defaultHost = "api.vapi.ai"
        
        init(clientToken: String, host: String) {
            self.host = host
            self.clientToken = clientToken
        }
    }
    
    public enum Event {
        case callDidStart
        case callDidEnd
        case error(Swift.Error)
    }
    
    // MARK: - Properties

    public let configuration: Configuration

    fileprivate let eventSubject = PassthroughSubject<Event, Never>()
    
    private let networkManager = NetworkManager()
    private var call: CallClient?
    
    // MARK: - Computed Properties
    
    private var clientToken: String {
        configuration.clientToken
    }
    
    /// A Combine publisher that clients can subscribe to for API events.
    public var eventPublisher: AnyPublisher<Event, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Init
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        
        Daily.setLogLevel(.error)
    }
    
    public convenience init(clientToken: String) {
        self.init(configuration: .init(clientToken: clientToken, host: Configuration.defaultHost))
    }
    
    public convenience init(clientToken: String, host: String? = nil) {
        self.init(configuration: .init(clientToken: clientToken, host: host ?? Configuration.defaultHost))
    }
    
    // MARK: - Instance Methods
    
    public func start(assistantId: String) throws {
        guard self.call == nil else {
            throw VapiError.existingCallInProgress
        }
        
        let body = ["assistantId": assistantId]
        
        self.startCall(body: body)
    }
    
    public func start(assistant: [String: Any]) throws {
        guard self.call == nil else {
            throw VapiError.existingCallInProgress
        }
        
        let body = ["assistant": assistant]
        
        self.startCall(body: body)
    }
    
    public func stop() {
        Task {
            do {
                try await call?.leave()
            } catch {
                self.callDidFail(with: error)
            }
        }
    }
    
    private func joinCall(with url: URL) {
        Task { @MainActor in
            do {
                let call = CallClient()
                call.delegate = self
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
            } catch {
                callDidFail(with: error)
            }
        }
    }
    
    private func makeURL(for path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = configuration.host
        components.path = path
        return components.url
    }
    
    private func makeURLRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(clientToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    private func startCall(body: [String: Any]) {
        guard let url = makeURL(for: "/call/web") else {
            callDidFail(with: VapiError.invalidURL)
            return
        }
        
        var request = makeURLRequest(for: url)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.callDidFail(with: error)
            return
        }
        
        Task { [request] in
            do {
                let response: WebCallResponse = try await networkManager.perform(request: request)
                joinCall(with: response.webCallUrl)
            } catch {
                callDidFail(with: error)
            }
        }
    }
    
    // MARK: - CallClientDelegate
    
    func callDidJoin() {
        print("Successfully joined call.")
        
        self.eventSubject.send(.callDidStart)
    }
    
    func callDidLeave() {
        print("Successfully left call.")
        
        self.eventSubject.send(.callDidEnd)
        self.call = nil
    }
    
    func callDidFail(with error: Swift.Error) {
        print("Got error while joining/leaving call: \(error).")
        
        self.eventSubject.send(.error(error))
        self.call = nil
    }
    
    public func callClient(_ callClient: CallClient, participantUpdated participant: Participant) {
        let isPlayable = participant.media?.microphone.state == Daily.MediaState.playable
        let isVapiSpeaker = participant.info.username == "Vapi Speaker"
        let shouldSendAppMessage = isPlayable && isVapiSpeaker
        
        guard shouldSendAppMessage else {
            return
        }
        
        do {
            let message: [String: Any] = ["message": "playable"]
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
            
            Task {
                try await self.call?.sendAppMessage(json: jsonData, to: .all)
            }
        } catch {
            print("Error sending message: \(error.localizedDescription)")
        }
    }
    
    public func callClient(_ callClient: CallClient, callStateUpdated state: CallState) {
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
