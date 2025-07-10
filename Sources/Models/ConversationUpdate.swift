import Foundation

public struct Message: Codable {
    public enum Role: String, Codable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
        case tool = "tool"
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }

    public let role: Role
    public let content: String? // For role=tool, has the response of the tool call. For role=assistant with tool_calls is nil.
    public let toolCalls: [ToolCall]? // Only for role=assistant with tool calls.
    public let toolCallId: String? // Only for role=tool, with tool response.

}

public struct ConversationUpdate: Codable {
    public let conversation: [Message]
}
