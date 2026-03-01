import Foundation

public struct ToolCallFunction: Codable {
    public let name: String
    public let arguments: String
}

public struct ToolCall: Codable {
    public let id: String
    public let type: String
    public let function: ToolCallFunction
}

public struct ToolCallList: Codable {
    public let toolCallList: [ToolCall]
}
