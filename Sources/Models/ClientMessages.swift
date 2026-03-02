import Foundation

public struct WorkflowNodeStarted: Codable {
    public let node: JSONValue
}

public struct AssistantStarted: Codable {
    public let newAssistant: JSONValue
}

public struct ToolCalls: Codable {
    public let toolWithToolCallList: [JSONValue]
    public let toolCallList: [JSONValue]
}

public struct ToolCallsResult: Codable {
    public let toolCallResult: JSONValue
}

public struct TransferUpdate: Codable {
    public let destination: JSONValue?
    public let toAssistant: JSONValue?
    public let fromAssistant: JSONValue?
    public let toStepRecord: JSONValue?
    public let fromStepRecord: JSONValue?
}

public struct LanguageChangeDetected: Codable {
    public let language: String
}

public struct ChatCreated: Codable {
    public let chat: JSONValue
}

public struct ChatDeleted: Codable {
    public let chat: JSONValue
}

public struct SessionCreated: Codable {
    public let session: JSONValue
}

public struct SessionUpdated: Codable {
    public let session: JSONValue
}

public struct SessionDeleted: Codable {
    public let session: JSONValue
}

public struct CallDeleted: Codable {}

public struct CallDeleteFailed: Codable {}
