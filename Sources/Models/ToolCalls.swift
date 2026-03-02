import Foundation

public struct ToolCalls: Codable {
    public let toolWithToolCallList: [JSONValue]
    public let toolCallList: [JSONValue]
}
