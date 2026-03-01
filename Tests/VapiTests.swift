import XCTest
@testable import Vapi

final class VapiTests: XCTestCase {
    private func makeVapi() -> Vapi {
        Vapi(publicKey: "test-public-key")
    }
    
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
    
    func testDecodeListeningMessageAsCallDidStart() throws {
        let vapi = makeVapi()
        let event = try vapi.decodeAppEvent(from: Data("\"listening\"".utf8))
        
        guard case .callDidStart? = event else {
            XCTFail("Expected callDidStart event")
            return
        }
    }
    
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
}
