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
        case workflowNodeStarted(WorkflowNodeStarted)
        case assistantStarted(AssistantStarted)
        case toolCalls(ToolCalls)
        case toolCallsResult(ToolCallsResult)
        case transferUpdate(TransferUpdate)
        case languageChangeDetected(LanguageChangeDetected)
        case chatCreated(ChatCreated)
        case chatDeleted(ChatDeleted)
        case sessionCreated(SessionCreated)
        case sessionUpdated(SessionUpdated)
        case sessionDeleted(SessionDeleted)
        case callDeleted(CallDeleted)
        case callDeleteFailed(CallDeleteFailed)
        case hang
        case error(Swift.Error)
    }

    /// Structured telemetry emitted whenever the SDK encounters an error.
    public struct TelemetryEvent {
        public let timestamp: Date
        public let operation: String
        public let errorCode: String
        public let message: String
        public let metadata: [String: String]
        public let underlyingError: String?
    }
    
    // MARK: - Properties

    public let configuration: Configuration

    fileprivate let eventSubject = PassthroughSubject<Event, Never>()
    public var telemetryHandler: ((TelemetryEvent) -> Void)?
    
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
                let wrappedError = self.wrapAsWebRTCFailure(error, operation: "stop.leave")
                self.callDidFail(with: wrappedError)
            }
        }
    }

    public func send(message: VapiMessage) async throws {
        let jsonData: Data

        do {
            jsonData = try JSONEncoder().encode(message)
        } catch {
            let wrappedError = wrapAsRequestBodyEncodingFailure(error)
            emitTelemetry(operation: "send.encodeMessage", error: wrappedError)
            throw wrappedError
        }

        // Debugging: Print the JSON data to verify its format (optional)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }

        do {
            // Send the JSON data to all targets
            try await self.call?.sendAppMessage(json: jsonData, to: .all)
        } catch {
            let wrappedError = wrapAsWebRTCFailure(error, operation: "send.appMessage")
            emitTelemetry(operation: "send.appMessage", error: wrappedError)
            throw wrappedError
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
            let wrappedError = wrapAsWebRTCFailure(error, operation: "setMuted")
            print("Failed to set mute state: \(wrappedError)")
            emitTelemetry(operation: "setMuted", error: wrappedError, metadata: ["muted": String(muted)])
            throw wrappedError
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
            let wrappedError = wrapAsWebRTCFailure(error, operation: "isMuted.toggle")
            print("Failed to toggle mute state: \(wrappedError)")
            emitTelemetry(operation: "isMuted.toggle", error: wrappedError)
            throw wrappedError
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
            let wrappedError = wrapAsWebRTCFailure(error, operation: "setAssistantMuted")
            print("Failed to set subscription state to \(muted ? "Staged" : "Subscribed") for remote assistant")
            emitTelemetry(operation: "setAssistantMuted", error: wrappedError, metadata: ["muted": String(muted)])
            throw wrappedError
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
            let wrappedError = wrapAsWebRTCFailure(error, operation: "setAudioDeviceType")
            print("Failed to change the AudioDeviceType with error: \(wrappedError)")
            emitTelemetry(
                operation: "setAudioDeviceType",
                error: wrappedError,
                metadata: ["audioDeviceType": String(describing: audioDeviceType)]
            )
            throw wrappedError
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
                let wrappedError = wrapAsWebRTCFailure(error, operation: "joinCall.joinOrStartRecording")
                callDidFail(with: wrappedError)
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

    private func wrapAsNetworkFailure(_ error: Error) -> VapiError {
        if let vapiError = error as? VapiError {
            return vapiError
        }

        return .networkFailure(underlying: error)
    }

    private func wrapAsWebRTCFailure(_ error: Error, operation: String) -> VapiError {
        if let vapiError = error as? VapiError {
            return vapiError
        }

        return .webRTCFailure(operation: operation, underlying: error)
    }

    private func wrapAsRequestBodyEncodingFailure(_ error: Error) -> VapiError {
        if let vapiError = error as? VapiError {
            return vapiError
        }

        return .requestBodyEncodingFailed(underlying: error)
    }

    private func emitTelemetry(operation: String, error: Error, metadata: [String: String] = [:]) {
        let vapiError = error as? VapiError
        let wrappedMessage = vapiError?.errorDescription
        let errorCode = vapiError?.code.rawValue ?? "unknown"
        let nsError = error as NSError
        let underlying = vapiError?.underlyingError ?? (nsError.userInfo[NSUnderlyingErrorKey] as? Error)
        let underlyingDescription = underlying.map { String(describing: $0) }
        let message = wrappedMessage ?? error.localizedDescription

        let telemetryEvent = TelemetryEvent(
            timestamp: Date(),
            operation: operation,
            errorCode: errorCode,
            message: message,
            metadata: metadata,
            underlyingError: underlyingDescription
        )
        telemetryHandler?(telemetryEvent)

        var payload: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: telemetryEvent.timestamp),
            "operation": telemetryEvent.operation,
            "errorCode": telemetryEvent.errorCode,
            "message": telemetryEvent.message,
            "metadata": telemetryEvent.metadata,
        ]
        if let underlyingDescription {
            payload["underlyingError"] = underlyingDescription
        }

        if
            let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
            print("VapiTelemetry \(jsonString)")
        } else {
            print("VapiTelemetry operation=\(operation) errorCode=\(errorCode) message=\(message)")
        }
    }
    
    private func startCall(body: [String: Any]) async throws -> WebCallResponse {
        guard let url = makeURL(for: "/call/web") else {
            let wrappedError = VapiError.urlConstructionFailed(host: configuration.host, path: "/call/web")
            callDidFail(with: wrappedError)
            throw wrappedError
        }
        
        var request = makeURLRequest(for: url)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            let wrappedError = wrapAsRequestBodyEncodingFailure(error)
            self.callDidFail(with: wrappedError)
            throw wrappedError
        }
        
        do {
            let response: WebCallResponse = try await networkManager.perform(request: request)
            let isVideoRecordingEnabled = response.artifactPlan?.videoRecordingEnabled ?? false
            joinCall(url: response.webCallUrl, recordVideo: isVideoRecordingEnabled)
            return response
        } catch {
            let wrappedError = wrapAsNetworkFailure(error)
            callDidFail(with: wrappedError)
            throw wrappedError
        }
    }
    
    private func unescapeAppMessage(_ jsonData: Data) -> (Data, String?) {
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            return (jsonData, nil)
        }

        // Remove the leading and trailing double quotes
        let trimmedString = jsonString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        // Replace escaped backslashes
        let unescapedString = trimmedString.replacingOccurrences(of: "\\\\", with: "\\")
        // Replace escaped double quotes
        let unescapedJSON = unescapedString.replacingOccurrences(of: "\\\"", with: "\"")

        let unescapedData = unescapedJSON.data(using: .utf8) ?? jsonData

        return (unescapedData, unescapedJSON)
    }
    
    private func normalizedAppMessageData(_ jsonData: Data) -> Data {
        guard
            let object = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
            let messageObject = object["message"] as? [String: Any],
            let messageData = try? JSONSerialization.data(withJSONObject: messageObject, options: [])
        else {
            return jsonData
        }
        
        return messageData
    }
    
    public func startLocalAudioLevelObserver() async throws {
        do {
            try await call?.startLocalAudioLevelObserver()
        } catch {
            let wrappedError = wrapAsWebRTCFailure(error, operation: "startLocalAudioLevelObserver")
            emitTelemetry(operation: "startLocalAudioLevelObserver", error: wrappedError)
            throw wrappedError
        }
    }
    
    public func startRemoteParticipantsAudioLevelObserver() async throws {
        do {
            try await call?.startRemoteParticipantsAudioLevelObserver()
        } catch {
            let wrappedError = wrapAsWebRTCFailure(error, operation: "startRemoteParticipantsAudioLevelObserver")
            emitTelemetry(operation: "startRemoteParticipantsAudioLevelObserver", error: wrappedError)
            throw wrappedError
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
        emitTelemetry(operation: "callDidFail", error: error)
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
                do {
                    try await call?.sendAppMessage(json: jsonData, to: .all)
                } catch {
                    let wrappedError = self.wrapAsWebRTCFailure(error, operation: "participantUpdated.sendAppMessage")
                    self.emitTelemetry(operation: "participantUpdated.sendAppMessage", error: wrappedError)
                }
            }
        } catch {
            let wrappedError = wrapAsRequestBodyEncodingFailure(error)
            emitTelemetry(operation: "participantUpdated.encodePlayableMessage", error: wrappedError)
            print("Error sending message: \(wrappedError.localizedDescription)")
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
            let (unescapedData, unescapedString) = unescapeAppMessage(jsonData)
            
            // Detect listening message first since it's a string rather than JSON
            guard unescapedString != "listening" else {
                eventSubject.send(.callDidStart)
                return
            }
            
            // Parse the JSON data generically to determine the type of event
            let decoder = JSONDecoder()
            let appMessageData = normalizedAppMessageData(unescapedData)
            let appMessage = try decoder.decode(AppMessage.self, from: appMessageData)
            // Parse the JSON data again, this time using the specific type
            let event: Event
            switch appMessage.type {
            case .functionCall:
                guard let messageDictionary = try JSONSerialization.jsonObject(with: appMessageData, options: []) as? [String: Any] else {
                    throw VapiError.decodingError(message: "App message isn't a valid JSON object")
                }
                
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
                event = Event.functionCall(functionCall)
            case .hang:
                event = Event.hang
            case .transcript, .transcriptFinal:
                let transcript = try decoder.decode(Transcript.self, from: appMessageData)
                event = Event.transcript(transcript)
            case .speechUpdate:
                let speechUpdate = try decoder.decode(SpeechUpdate.self, from: appMessageData)
                event = Event.speechUpdate(speechUpdate)
            case .metadata:
                let metadata = try decoder.decode(Metadata.self, from: appMessageData)
                event = Event.metadata(metadata)
            case .conversationUpdate:
                let conv = try decoder.decode(ConversationUpdate.self, from: appMessageData)
                event = Event.conversationUpdate(conv)
            case .statusUpdate:
                let statusUpdate = try decoder.decode(StatusUpdate.self, from: appMessageData)
                event = Event.statusUpdate(statusUpdate)
            case .modelOutput:
                let modelOutput = try decoder.decode(ModelOutput.self, from: appMessageData)
                event = Event.modelOutput(modelOutput)
            case .userInterrupted:
                let userInterrupted = UserInterrupted()
                event = Event.userInterrupted(userInterrupted)
            case .voiceInput:
                let voiceInput = try decoder.decode(VoiceInput.self, from: appMessageData)
                event = Event.voiceInput(voiceInput)
            case .workflowNodeStarted:
                let workflowNodeStarted = try decoder.decode(WorkflowNodeStarted.self, from: appMessageData)
                event = Event.workflowNodeStarted(workflowNodeStarted)
            case .assistantStarted:
                let assistantStarted = try decoder.decode(AssistantStarted.self, from: appMessageData)
                event = Event.assistantStarted(assistantStarted)
            case .toolCalls:
                let toolCalls = try decoder.decode(ToolCalls.self, from: appMessageData)
                event = Event.toolCalls(toolCalls)
            case .toolCallsResult:
                let toolCallsResult = try decoder.decode(ToolCallsResult.self, from: appMessageData)
                event = Event.toolCallsResult(toolCallsResult)
            case .transferUpdate:
                let transferUpdate = try decoder.decode(TransferUpdate.self, from: appMessageData)
                event = Event.transferUpdate(transferUpdate)
            case .languageChangeDetected:
                let languageChangeDetected = try decoder.decode(LanguageChangeDetected.self, from: appMessageData)
                event = Event.languageChangeDetected(languageChangeDetected)
            case .chatCreated:
                let chatCreated = try decoder.decode(ChatCreated.self, from: appMessageData)
                event = Event.chatCreated(chatCreated)
            case .chatDeleted:
                let chatDeleted = try decoder.decode(ChatDeleted.self, from: appMessageData)
                event = Event.chatDeleted(chatDeleted)
            case .sessionCreated:
                let sessionCreated = try decoder.decode(SessionCreated.self, from: appMessageData)
                event = Event.sessionCreated(sessionCreated)
            case .sessionUpdated:
                let sessionUpdated = try decoder.decode(SessionUpdated.self, from: appMessageData)
                event = Event.sessionUpdated(sessionUpdated)
            case .sessionDeleted:
                let sessionDeleted = try decoder.decode(SessionDeleted.self, from: appMessageData)
                event = Event.sessionDeleted(sessionDeleted)
            case .callDeleted:
                let callDeleted = CallDeleted()
                event = Event.callDeleted(callDeleted)
            case .callDeleteFailed:
                let callDeleteFailed = CallDeleteFailed()
                event = Event.callDeleteFailed(callDeleteFailed)
            }
            eventSubject.send(event)
        } catch {
            let messageText = String(data: jsonData, encoding: .utf8)
            print("Error parsing app message \"\(messageText ?? "")\": \(error.localizedDescription)")
            emitTelemetry(
                operation: "appMessage.decode",
                error: error,
                metadata: ["rawMessage": messageText ?? ""]
            )
        }
    }
}
