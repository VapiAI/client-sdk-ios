import Foundation

public struct Message: Codable {
    public enum Role: String, Codable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
        case tool = "tool"
    }
    
    public let role: Role
    public let content: String? // For role=tool, has the response of the tool call. For role=assistant with tool_calls is nil.
    public let tool_calls: [ToolCall]? // Only for role=assistant with tool calls.
    public let tool_call_id: String? // Only for role=tool, with tool response.

}

public struct ConversationUpdate: Codable {
    public let conversation: [Message]
}
