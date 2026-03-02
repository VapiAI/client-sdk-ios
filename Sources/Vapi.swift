import Combine
import Daily
import Foundation

// Define the nested message structure
struct VapiMessageContent: Encodable {
    public let role: String
    public let content: String
}

// Define the top-level app message structure
public struct VapiMessage: Encodable {
    public let type: String
    let message: VapiMessageContent

    public init(type: String, role: String, content: String) {
        self.type = type
        self.message = VapiMessageContent(role: role, content: content)
    }
}

public final class Vapi: CallClientDelegate {
    
    // MARK: - Supporting Types
    
    /// A configuration that contains the host URL and the client token.
    ///
    /// This configuration is serializable via `Codable`.
    public struct Configuration: Codable, Hashable, Sendable {
        public var host: String
        public var publicKey: String
        fileprivate static let defaultHost = "api.vapi.ai"
        
        init(publicKey: String, host: String) {
            self.host = host
            self.publicKey = publicKey
        }
    }

    public enum Event {
        case callDidStart
        case callDidEnd
        case transcript(Transcript)
        case functionCall(FunctionCall)
        case speechUpdate(SpeechUpdate)
        case metadata(Metadata)
        case conversationUpdate(ConversationUpdate)
        case statusUpdate(StatusUpdate)
        case modelOutput(ModelOutput)
        case userInterrupted(UserInterrupted)
        case voiceInput(VoiceInput)
        case workflowNodeStarted([String: Any])
        case assistantStarted([String: Any])
        case toolCalls([String: Any])
        case toolCallsResult([String: Any])
        case transferUpdate([String: Any])
        case languageChangeDetected([String: Any])
        case chatCreated([String: Any])
        case chatDeleted([String: Any])
        case sessionCreated([String: Any])
        case sessionUpdated([String: Any])
        case sessionDeleted([String: Any])
        case callDeleted([String: Any])
        case callDeleteFailed([String: Any])
        case unknown(type: String, payload: [String: Any])
        case hang
        case error(Swift.Error)
    }
    
    // MARK: - Properties

    public let configuration: Configuration

    fileprivate let eventSubject = PassthroughSubject<Event, Never>()
    
    private let networkManager = NetworkManager()
    private var call: CallClient?
    
    // MARK: - Computed Properties
    
    private var publicKey: String {
        configuration.publicKey
    }
    
    /// A Combine publisher that clients can subscribe to for API events.
    public var eventPublisher: AnyPublisher<Event, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    @MainActor public var localAudioLevel: Float? {
        call?.localAudioLevel
    }
    
    @MainActor public var remoteAudioLevel: Float? {
        call?.remoteParticipantsAudioLevel.values.first
    }
    
    @MainActor public var audioDeviceType: AudioDeviceType? {
        call?.audioDevice
    }
    
    private var isMicrophoneMuted: Bool = false
    private var isAssistantMuted: Bool = false
    
    // MARK: - Init
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        
        Daily.setLogLevel(.off)
    }
    
    public convenience init(publicKey: String) {
        self.init(configuration: .init(publicKey: publicKey, host: Configuration.defaultHost))
    }
    
    public convenience init(publicKey: String, host: String? = nil) {
        self.init(configuration: .init(publicKey: publicKey, host: host ?? Configuration.defaultHost))
    }
    
    // MARK: - Instance Methods
    
    public func start(
        assistantId: String, metadata: [String: Any] = [:], assistantOverrides: [String: Any] = [:]
    ) async throws -> WebCallResponse {
        guard self.call == nil else {
            throw VapiError.existingCallInProgress
        }
        
        let body = [
            "assistantId": assistantId, "metadata": metadata, "assistantOverrides": assistantOverrides
        ] as [String: Any]
        
        return try await self.startCall(body: body)
    }
    
    public func start(
        assistant: [String: Any], metadata: [String: Any] = [:], assistantOverrides: [String: Any] = [:]
    ) async throws -> WebCallResponse {
        guard self.call == nil else {
            throw VapiError.existingCallInProgress
        }
        
        let body = [
            "assistant": assistant, "metadata": metadata, "assistantOverrides": assistantOverrides
        ] as [String: Any]

        return try await self.startCall(body: body)
    }
    
    public func stop() {
        Task {
            do {
                try await call?.leave()
                call = nil
            } catch {
                self.callDidFail(with: error)
            }
        }
    }

    public func send(message: VapiMessage) async throws {
        do {
          // Use JSONEncoder to convert the message to JSON Data
          let jsonData = try JSONEncoder().encode(message)
          
          // Debugging: Print the JSON data to verify its format (optional)
          if let jsonString = String(data: jsonData, encoding: .utf8) {
              print(jsonString)
          }
          
          // Send the JSON data to all targets
          try await self.call?.sendAppMessage(json: jsonData, to: .all)
      } catch {
          // Handle encoding error
          print("Error encoding message to JSON: \(error)")
          throw error // Re-throw the error to be handled by the caller
      }
    }

    public func setMuted(_ muted: Bool) async throws {
        guard let call = self.call else {
            throw VapiError.noCallInProgress
        }
        
        do {
            try await call.setInputEnabled(.microphone, !muted)
            self.isMicrophoneMuted = muted
            if muted {
                print("Audio muted")
            } else {
                print("Audio unmuted")
            }
        } catch {
            print("Failed to set mute state: \(error)")
            throw error
        }
    }

    public func isMuted() async throws {
        guard let call = self.call else {
            throw VapiError.noCallInProgress
        }
        
        let shouldBeMuted = !self.isMicrophoneMuted
        
        do {
            try await call.setInputEnabled(.microphone, !shouldBeMuted)
            self.isMicrophoneMuted = shouldBeMuted
            if shouldBeMuted {
                print("Audio muted")
            } else {
                print("Audio unmuted")
            }
        } catch {
            print("Failed to toggle mute state: \(error)")
            throw error
        }
    }
    
    public func setAssistantMuted(_ muted: Bool) async throws {
        guard let call else {
            throw VapiError.noCallInProgress
        }
        
        do {
            let remoteParticipants = await call.participants.remote
            
            // First retrieve the assistant where the user name is "Vapi Speaker", this is the one we will unsubscribe from or subscribe too
            guard let assistant = remoteParticipants.first(where: { $0.value.info.username == .remoteParticipantVapiSpeaker })?.value else { return }
            
            // Then we update the subscription to `staged` if muted which means we don't receive audio
            // but we'll still receive the response. If we unmute it we set it back to `subscribed` so we start
            // receiving audio again. This is taken from Daily examples.
            _ = try await call.updateSubscriptions(
                forParticipants: .set([
                    assistant.id: .set(
                        profile: .set(.base),
                        media: .set(
                            microphone: .set(
                                subscriptionState: muted ? .set(.staged) : .set(.subscribed)
                            )
                        )
                    )
                ])
            )
            isAssistantMuted = muted
        } catch {
            print("Failed to set subscription state to \(muted ? "Staged" : "Subscribed") for remote assistant")
            throw error
        }
    }
    
    /// This method sets the `AudioDeviceType` of the current called to the passed one if it's not the same as the current one
    /// - Parameter audioDeviceType: can either be `bluetooth`, `speakerphone`, `wired` or `earpiece`
    public func setAudioDeviceType(_ audioDeviceType: AudioDeviceType) async throws {
        guard let call else {
            throw VapiError.noCallInProgress
        }
        
        guard await self.audioDeviceType != audioDeviceType else {
            print("Not updating AudioDeviceType because it is the same")
            return
        }
        
        do {
            try await call.setPreferredAudioDevice(audioDeviceType)
        } catch {
            print("Failed to change the AudioDeviceType with error: \(error)")
            throw error
        }
    }

    private func joinCall(url: URL, recordVideo: Bool) {
        Task { @MainActor in
            do {
                let call = CallClient()
                call.delegate = self
                self.call = call
                
                _ = try await call.join(
                    url: url,
                    settings: .init(
                        inputs: .set(
                            camera: .set(.enabled(recordVideo)),
                            microphone: .set(.enabled(true))
                        )
                    )
                )
                
                if(!recordVideo) {
                    return
                }
                    
                _ = try await call.startRecording(
                    streamingSettings: .init(
                        video: .init(
                            width:1280,
                            height:720,
                            backgroundColor: "#FF1F2D3D"
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
        // Check if the host is localhost, set the scheme to http and port to 3001; otherwise, set the scheme to https
        if configuration.host == "localhost" {
            components.scheme = "http"
            components.port = 3001
        } else {
            components.scheme = "https"
        }
        components.host = configuration.host
        components.path = path
        return components.url
    }
    
    private func makeURLRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(publicKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    private func startCall(body: [String: Any]) async throws -> WebCallResponse {
        guard let url = makeURL(for: "/call/web") else {
            callDidFail(with: VapiError.invalidURL)
            throw VapiError.customError("Unable to create web call")
        }
        
        var request = makeURLRequest(for: url)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.callDidFail(with: error)
            throw VapiError.customError(error.localizedDescription)
        }
        
        do {
            let response: WebCallResponse = try await networkManager.perform(request: request)
            let isVideoRecordingEnabled = response.artifactPlan?.videoRecordingEnabled ?? false
            joinCall(url: response.webCallUrl, recordVideo: isVideoRecordingEnabled)
            return response
        } catch {
            callDidFail(with: error)
            throw VapiError.customError(error.localizedDescription)
        }
    }
    
    private enum NormalizedAppMessage {
        case listening
        case json(Data)
    }

    private func normalizeAppMessage(_ jsonData: Data) -> NormalizedAppMessage {
        var currentData = jsonData

        for _ in 0..<5 {
            if let rawString = String(data: currentData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               rawString == "listening"
            {
                return .listening
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: currentData, options: []) else {
                break
            }

            if let encodedString = jsonObject as? String {
                let trimmed = encodedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "listening" {
                    return .listening
                }

                currentData = Data(trimmed.utf8)
                continue
            }

            guard let dictionary = jsonObject as? [String: Any] else {
                break
            }

            if let nestedMessage = dictionary["message"] {
                if let nestedMessageString = nestedMessage as? String {
                    let trimmed = nestedMessageString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed == "listening" {
                        return .listening
                    }

                    currentData = Data(trimmed.utf8)
                    continue
                }

                if JSONSerialization.isValidJSONObject(nestedMessage),
                   let nestedData = try? JSONSerialization.data(withJSONObject: nestedMessage, options: [])
                {
                    currentData = nestedData
                    continue
                }
            }

            return .json(currentData)
        }

        if let jsonString = String(data: currentData, encoding: .utf8) {
            let trimmedString = jsonString
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

            if trimmedString == "listening" {
                return .listening
            }

            let unescapedString = trimmedString
                .replacingOccurrences(of: "\\\\", with: "\\")
                .replacingOccurrences(of: "\\\"", with: "\"")

            if let unescapedData = unescapedString.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: unescapedData, options: [])) != nil
            {
                return .json(unescapedData)
            }
        }

        return .json(currentData)
    }

    func decodeAppEvent(from jsonData: Data) throws -> Event? {
        let normalizedMessage = normalizeAppMessage(jsonData)

        switch normalizedMessage {
        case .listening:
            return .callDidStart
        case .json(let normalizedData):
            let decoder = JSONDecoder()
            let appMessage = try decoder.decode(AppMessage.self, from: normalizedData)

            guard let messageDictionary = try JSONSerialization.jsonObject(with: normalizedData, options: []) as? [String: Any] else {
                throw VapiError.decodingError(message: "App message isn't a valid JSON object")
            }

            switch appMessage.messageType {
            case .functionCall:
                guard let functionCallDictionary = messageDictionary["functionCall"] as? [String: Any] else {
                    throw VapiError.decodingError(message: "App message missing functionCall")
                }

                guard let name = functionCallDictionary[FunctionCall.CodingKeys.name.stringValue] as? String else {
                    throw VapiError.decodingError(message: "App message missing name")
                }

                guard let parameters = functionCallDictionary[FunctionCall.CodingKeys.parameters.stringValue] as? [String: Any] else {
                    throw VapiError.decodingError(message: "App message missing parameters")
                }

                let functionCall = FunctionCall(name: name, parameters: parameters)
                return .functionCall(functionCall)
            case .hang:
                return .hang
            case .transcript:
                let transcript = try decoder.decode(Transcript.self, from: normalizedData)
                return .transcript(transcript)
            case .speechUpdate:
                let speechUpdate = try decoder.decode(SpeechUpdate.self, from: normalizedData)
                return .speechUpdate(speechUpdate)
            case .metadata:
                let metadata = try decoder.decode(Metadata.self, from: normalizedData)
                return .metadata(metadata)
            case .conversationUpdate:
                let conversationUpdate = try decoder.decode(ConversationUpdate.self, from: normalizedData)
                return .conversationUpdate(conversationUpdate)
            case .statusUpdate:
                let statusUpdate = try decoder.decode(StatusUpdate.self, from: normalizedData)
                return .statusUpdate(statusUpdate)
            case .modelOutput:
                let modelOutput = try decoder.decode(ModelOutput.self, from: normalizedData)
                return .modelOutput(modelOutput)
            case .userInterrupted:
                return .userInterrupted(UserInterrupted())
            case .voiceInput:
                let voiceInput = try decoder.decode(VoiceInput.self, from: normalizedData)
                return .voiceInput(voiceInput)
            case .workflowNodeStarted:
                return .workflowNodeStarted(messageDictionary)
            case .assistantStarted:
                return .assistantStarted(messageDictionary)
            case .toolCalls:
                return .toolCalls(messageDictionary)
            case .toolCallsResult:
                return .toolCallsResult(messageDictionary)
            case .transferUpdate:
                return .transferUpdate(messageDictionary)
            case .languageChangeDetected:
                return .languageChangeDetected(messageDictionary)
            case .chatCreated:
                return .chatCreated(messageDictionary)
            case .chatDeleted:
                return .chatDeleted(messageDictionary)
            case .sessionCreated:
                return .sessionCreated(messageDictionary)
            case .sessionUpdated:
                return .sessionUpdated(messageDictionary)
            case .sessionDeleted:
                return .sessionDeleted(messageDictionary)
            case .callDeleted:
                return .callDeleted(messageDictionary)
            case .callDeleteFailed:
                return .callDeleteFailed(messageDictionary)
            case .unknown:
                return .unknown(type: appMessage.type, payload: messageDictionary)
            }
        }
    }
    
    public func startLocalAudioLevelObserver() async throws {
        do {
            try await call?.startLocalAudioLevelObserver()
        } catch {
            throw error
        }
    }
    
    public func startRemoteParticipantsAudioLevelObserver() async throws {
        do {
            try await call?.startRemoteParticipantsAudioLevelObserver()
        } catch {
            throw error
        }
    }
    
    // MARK: - CallClientDelegate
    
    func callDidJoin() {
        print("Successfully joined call.")
        // Note: the call start event will be sent once the assistant has joined and is listening
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
                try await call?.sendAppMessage(json: jsonData, to: .all)
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
    
    public func callClient(_ callClient: Daily.CallClient, appMessageAsJson jsonData: Data, from participantID: Daily.ParticipantID) {
        do {
            guard let event = try decodeAppEvent(from: jsonData) else {
                return
            }

            eventSubject.send(event)
        } catch {
            let messageText = String(data: jsonData, encoding: .utf8)
            print("Error parsing app message \"\(messageText ?? "")\": \(error.localizedDescription)")
        }
    }
}
