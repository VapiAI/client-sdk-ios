import XCTest
import Combine
@testable import Vapi

final class MessageParsingTests: XCTestCase {
    
    func testParseMessagesWithToolCallRole() throws {
        let jsonString = """
        {
          "conversation": [
            {
              "role": "system",
              "content": "System message"
            },
            {
              "role": "assistant",
              "content": "Assistant message",
              "tool_calls": [
                {
                  "type": "function",
                  "id": "tool123",
                  "function": {
                    "name": "start_exercise",
                    "arguments": "{}"
                  }
                }
              ]
            },
            {
              "role": "tool",
              "tool_call_id": "tool123",
              "content": "Tool Result"
            },
            {
              "role": "tool_calls",
              "content": null,
              "tool_calls": [
                {
                  "type": "function",
                  "id": "tool456",
                  "function": {
                    "name": "another_function",
                    "arguments": "{}"
                  }
                }
              ]
            }
          ]
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // This should not throw with our updated Role enum
        let conversationUpdate = try decoder.decode(ConversationUpdate.self, from: jsonData)
        
        XCTAssertEqual(conversationUpdate.conversation.count, 4)
        XCTAssertEqual(conversationUpdate.conversation[0].role, Message.Role.system)
        XCTAssertEqual(conversationUpdate.conversation[1].role, Message.Role.assistant)
        XCTAssertEqual(conversationUpdate.conversation[2].role, Message.Role.tool)
        XCTAssertEqual(conversationUpdate.conversation[3].role, Message.Role.toolCalls)
        
        // Verify tool calls are properly parsed
        XCTAssertNotNil(conversationUpdate.conversation[1].tool_calls)
        XCTAssertEqual(conversationUpdate.conversation[1].tool_calls?.count, 1)
        XCTAssertEqual(conversationUpdate.conversation[1].tool_calls?[0].function?.name, "start_exercise")
        
        // Verify tool_call_id is properly parsed
        XCTAssertEqual(conversationUpdate.conversation[2].tool_call_id, "tool123")
    }
    
    func testToolCallsInMessageAreExtractedAsFunctionCalls() throws {
        let appMessageString = """
        {
          "type": "conversation-update",
          "conversation": [
            {
              "role": "system",
              "content": "System message"
            },
            {
              "role": "tool_calls",
              "tool_calls": [
                {
                  "type": "function",
                  "id": "tool456",
                  "function": {
                    "name": "another_function",
                    "arguments": "{}"
                  }
                }
              ]
            }
          ]
        }
        """
        
        let appMessageData = appMessageString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let appMessage = try decoder.decode(AppMessage.self, from: appMessageData)
        
        XCTAssertEqual(appMessage.type, AppMessage.MessageType.conversationUpdate)
        
        let conversationUpdate = try decoder.decode(ConversationUpdate.self, from: appMessageData)
        XCTAssertEqual(conversationUpdate.conversation.count, 2)
        
        let lastMessage = conversationUpdate.conversation.last!
        XCTAssertEqual(lastMessage.role, Message.Role.toolCalls)
        XCTAssertNotNil(lastMessage.tool_calls)
        XCTAssertEqual(lastMessage.tool_calls!.count, 1)
        
        let toolCall = lastMessage.tool_calls![0]
        XCTAssertEqual(toolCall.function?.name, "another_function")
        XCTAssertEqual(toolCall.function?.arguments, "{}")
    }
    
    func testParseTimestampedMessagesArray() throws {
        let appMessageString = """
        {
          "type": "conversation-update",
          "conversation": [
            {
              "role": "system",
              "content": "System message"
            }
          ],
          "messages": [
            {
              "role": "system",
              "message": "System message",
              "time": 1741093883580,
              "secondsFromStart": 0
            },
            {
              "role": "bot",
              "message": "Bot message",
              "time": 1741093885838,
              "endTime": 1741093886618,
              "secondsFromStart": 1.8399999,
              "duration": 780,
              "source": ""
            },
            {
              "role": "user",
              "message": "User message",
              "time": 1741093897088,
              "endTime": 1741093898238,
              "secondsFromStart": 13.09,
              "duration": 1150
            },
            {
              "toolCalls": [
                {
                  "type": "function",
                  "id": "tool123",
                  "function": {
                    "name": "test_function",
                    "arguments": "{}"
                  }
                }
              ],
              "role": "tool_calls",
              "message": "",
              "time": 1741093903823,
              "secondsFromStart": 15.179
            }
          ],
          "messagesOpenAIFormatted": []
        }
        """
        
        let appMessageData = appMessageString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let conversationUpdate = try decoder.decode(ConversationUpdate.self, from: appMessageData)
        
        // Check that messages array was parsed correctly
        XCTAssertNotNil(conversationUpdate.messages)
        XCTAssertEqual(conversationUpdate.messages?.count, 4)
        
        // Verify the first message (system)
        XCTAssertEqual(conversationUpdate.messages?[0].role, TimestampedMessage.Role.system)
        XCTAssertEqual(conversationUpdate.messages?[0].message, "System message")
        XCTAssertEqual(conversationUpdate.messages?[0].time, 1741093883580.0)
        
        // Verify the bot message
        XCTAssertEqual(conversationUpdate.messages?[1].role, TimestampedMessage.Role.bot)
        XCTAssertEqual(conversationUpdate.messages?[1].message, "Bot message")
        XCTAssertEqual(conversationUpdate.messages?[1].time, 1741093885838.0)
        XCTAssertEqual(conversationUpdate.messages?[1].endTime, 1741093886618.0)
        XCTAssertEqual(conversationUpdate.messages?[1].duration, 780.0)
        
        // Verify the user message
        XCTAssertEqual(conversationUpdate.messages?[2].role, TimestampedMessage.Role.user)
        XCTAssertEqual(conversationUpdate.messages?[2].message, "User message")
        
        // Verify the tool_calls message
        XCTAssertEqual(conversationUpdate.messages?[3].role, TimestampedMessage.Role.toolCalls)
        XCTAssertNotNil(conversationUpdate.messages?[3].toolCalls)
        XCTAssertEqual(conversationUpdate.messages?[3].toolCalls?.count, 1)
        
        let toolCall = conversationUpdate.messages?[3].toolCalls?[0]
        XCTAssertEqual(toolCall?.function?.name, "test_function")
        XCTAssertEqual(toolCall?.function?.arguments, "{}")
        XCTAssertEqual(toolCall?.id, "tool123")
    }
}

