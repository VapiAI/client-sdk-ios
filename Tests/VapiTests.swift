import XCTest
@testable import Vapi

final class VapiTests: XCTestCase {
    private func makeVapi() -> Vapi {
        Vapi(publicKey: "test-public-key")
    }

    // MARK: - Listening / callDidStart

    func testDecodeListeningMessageAsCallDidStart() throws {
        let vapi = makeVapi()
        let event = try vapi.decodeAppEvent(from: Data("\"listening\"".utf8))

        guard case .callDidStart? = event else {
            XCTFail("Expected callDidStart event")
            return
        }
    }

    // MARK: - Escaped message handling

    func testDecodeEscapedAssistantStartedMessage() throws {
        let vapi = makeVapi()
        let escapedMessage = "\"{\\\"type\\\":\\\"assistant.started\\\",\\\"newAssistant\\\":{\\\"id\\\":\\\"assistant-id\\\"}}\""
        let data = Data(escapedMessage.utf8)

        let event = try vapi.decodeAppEvent(from: data)

        guard case .assistantStarted(let payload)? = event else {
            XCTFail("Expected assistantStarted event")
            return
        }

        XCTAssertEqual(payload["type"] as? String, "assistant.started")
    }

    // MARK: - Wrapped message handling

    func testDecodeWrappedMessagePayload() throws {
        let vapi = makeVapi()
        let message = """
        {
          "message": {
            "type": "workflow.node.started",
            "node": {
              "id": "node-1"
            }
          }
        }
        """

        let event = try vapi.decodeAppEvent(from: Data(message.utf8))

        guard case .workflowNodeStarted(let payload)? = event else {
            XCTFail("Expected workflowNodeStarted event")
            return
        }

        XCTAssertEqual(payload["type"] as? String, "workflow.node.started")
    }

    // MARK: - Type alias handling

    func testDecodeToolCompletedAliasAsToolCallsResult() throws {
        let vapi = makeVapi()
        let message = """
        {
          "type": "tool.completed",
          "toolCallResult": {
            "name": "lookup",
            "result": "ok"
          }
        }
        """

        let event = try vapi.decodeAppEvent(from: Data(message.utf8))

        guard case .toolCallsResult(let payload)? = event else {
            XCTFail("Expected toolCallsResult event")
            return
        }

        XCTAssertEqual(payload["type"] as? String, "tool.completed")
        XCTAssertNotNil(payload["toolCallResult"])
    }

    func testDecodeLanguageChangedAlias() throws {
        let vapi = makeVapi()
        let message = """
        {
          "type": "language-changed",
          "language": "es"
        }
        """

        let event = try vapi.decodeAppEvent(from: Data(message.utf8))

        guard case .languageChangeDetected(let payload)? = event else {
            XCTFail("Expected languageChangeDetected event")
            return
        }

        XCTAssertEqual(payload["language"] as? String, "es")
    }

    // MARK: - Unknown message type

    func testDecodeUnknownMessageType() throws {
        let vapi = makeVapi()
        let message = """
        {
          "type": "my-new-event",
          "foo": "bar"
        }
        """

        let event = try vapi.decodeAppEvent(from: Data(message.utf8))

        guard case .unknown(let type, let payload)? = event else {
            XCTFail("Expected unknown event")
            return
        }

        XCTAssertEqual(type, "my-new-event")
        XCTAssertEqual(payload["foo"] as? String, "bar")
    }

    // MARK: - All new client message types

    func testDecodeAssistantStarted() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "assistant.started", "newAssistant": { "id": "a1" } }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .assistantStarted? = event else {
            XCTFail("Expected assistantStarted event"); return
        }
    }

    func testDecodeWorkflowNodeStarted() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "workflow.node.started", "node": { "id": "n1" } }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .workflowNodeStarted? = event else {
            XCTFail("Expected workflowNodeStarted event"); return
        }
    }

    func testDecodeToolCalls() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "tool-calls", "toolCallList": [] }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .toolCalls? = event else {
            XCTFail("Expected toolCalls event"); return
        }
    }

    func testDecodeToolCallsResult() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "tool-calls-result", "toolCallResult": {} }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .toolCallsResult? = event else {
            XCTFail("Expected toolCallsResult event"); return
        }
    }

    func testDecodeTransferUpdate() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "transfer-update", "destination": { "type": "assistant" } }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .transferUpdate? = event else {
            XCTFail("Expected transferUpdate event"); return
        }
    }

    func testDecodeLanguageChangeDetected() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "language-change-detected", "language": "fr" }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .languageChangeDetected(let payload)? = event else {
            XCTFail("Expected languageChangeDetected event"); return
        }
        XCTAssertEqual(payload["language"] as? String, "fr")
    }

    func testDecodeChatCreated() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "chat.created", "chat": { "id": "c1" } }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .chatCreated? = event else {
            XCTFail("Expected chatCreated event"); return
        }
    }

    func testDecodeChatDeleted() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "chat.deleted", "chat": { "id": "c1" } }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .chatDeleted? = event else {
            XCTFail("Expected chatDeleted event"); return
        }
    }

    func testDecodeSessionCreated() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "session.created", "session": { "id": "s1" } }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .sessionCreated? = event else {
            XCTFail("Expected sessionCreated event"); return
        }
    }

    func testDecodeSessionUpdated() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "session.updated", "session": { "id": "s1" } }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .sessionUpdated? = event else {
            XCTFail("Expected sessionUpdated event"); return
        }
    }

    func testDecodeSessionDeleted() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "session.deleted", "session": { "id": "s1" } }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .sessionDeleted? = event else {
            XCTFail("Expected sessionDeleted event"); return
        }
    }

    func testDecodeCallDeleted() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "call.deleted" }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .callDeleted? = event else {
            XCTFail("Expected callDeleted event"); return
        }
    }

    func testDecodeCallDeleteFailed() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "call.delete.failed" }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .callDeleteFailed? = event else {
            XCTFail("Expected callDeleteFailed event"); return
        }
    }

    // MARK: - Transcript with type suffix normalization

    func testDecodeTranscriptWithTypeSuffix() throws {
        let vapi = makeVapi()
        let message = """
        {
          "type": "transcript[transcriptType=\\"final\\"]",
          "role": "user",
          "transcriptType": "final",
          "transcript": "Hello"
        }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .transcript(let transcript)? = event else {
            XCTFail("Expected transcript event"); return
        }
        XCTAssertEqual(transcript.transcript, "Hello")
    }

    // MARK: - Existing message types still work

    func testDecodeHangMessage() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "hang" }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .hang? = event else {
            XCTFail("Expected hang event"); return
        }
    }

    func testDecodeSpeechUpdateMessage() throws {
        let vapi = makeVapi()
        let message = """
        { "type": "speech-update", "status": "started", "role": "user" }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .speechUpdate(let update)? = event else {
            XCTFail("Expected speechUpdate event"); return
        }
        XCTAssertEqual(update.status, .started)
        XCTAssertEqual(update.role, .user)
    }

    func testDecodeConversationUpdateWithMessagesKey() throws {
        let vapi = makeVapi()
        let message = """
        {
          "type": "conversation-update",
          "messages": [
            { "role": "user", "content": "Hi" },
            { "role": "assistant", "content": "Hello!" }
          ]
        }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .conversationUpdate(let update)? = event else {
            XCTFail("Expected conversationUpdate event"); return
        }
        XCTAssertEqual(update.conversation.count, 2)
    }

    func testDecodeConversationUpdateWithToolRole() throws {
        let vapi = makeVapi()
        let message = """
        {
          "type": "conversation-update",
          "messages": [
            { "role": "tool", "content": "result" }
          ]
        }
        """
        let event = try vapi.decodeAppEvent(from: Data(message.utf8))
        guard case .conversationUpdate(let update)? = event else {
            XCTFail("Expected conversationUpdate event"); return
        }
        XCTAssertEqual(update.conversation.first?.role, .tool)
    }
}
