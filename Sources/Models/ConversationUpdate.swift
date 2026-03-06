import Foundation

public struct Message: Codable {
    public enum Role: String, Codable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
        case tool = "tool"
        case toolCalls = "tool_calls"
        case bot = "bot"
    }
    
    public let role: Role
    public let content: String?
    public let tool_calls: [ToolCall]?
    public let tool_call_id: String?
    
    enum CodingKeys: String, CodingKey {
        case role
        case content
        case tool_calls
        case tool_call_id
    }
}

public struct TimestampedMessage: Codable {
    public enum Role: String, Codable {
        case user = "user"
        case bot = "bot"
        case system = "system"
        case tool = "tool"
        case toolCalls = "tool_calls"
    }
    
    public let role: Role
    public let message: String?
    public let time: Double
    public let endTime: Double?
    public let secondsFromStart: Double?
    public let duration: Double?
    public let toolCalls: [ToolCall]?
    
    enum CodingKeys: String, CodingKey {
        case role
        case message
        case time
        case endTime
        case secondsFromStart
        case duration
        case toolCalls
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(Role.self, forKey: .role)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        toolCalls = try container.decodeIfPresent([ToolCall].self, forKey: .toolCalls)
        
        if let timeStr = try? container.decodeIfPresent(String.self, forKey: .time),
           let timeDouble = Double(timeStr) {
            time = timeDouble
        } else {
            time = try container.decode(Double.self, forKey: .time)
        }
        
        if let endTimeStr = try? container.decodeIfPresent(String.self, forKey: .endTime),
           let endTimeDouble = Double(endTimeStr) {
            endTime = endTimeDouble
        } else {
            endTime = try container.decodeIfPresent(Double.self, forKey: .endTime)
        }
        
        secondsFromStart = try container.decodeIfPresent(Double.self, forKey: .secondsFromStart)
        
        if let durationStr = try? container.decodeIfPresent(String.self, forKey: .duration),
           let durationDouble = Double(durationStr) {
            duration = durationDouble
        } else {
            duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        }
    }
}

public struct ToolCall: Codable {
    public let type: String?
    public let id: String?
    public let function: ToolFunction?
}

public struct ToolFunction: Codable {
    public let name: String
    public let arguments: String
}

public struct ConversationUpdate: Codable {
    public let conversation: [Message]
    public let messages: [TimestampedMessage]?
    public let messagesOpenAIFormatted: [String]?
    
    enum CodingKeys: String, CodingKey {
        case conversation
        case messages
        case messagesOpenAIFormatted
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conversation = try container.decode([Message].self, forKey: .conversation)
        messages = try container.decodeIfPresent([TimestampedMessage].self, forKey: .messages)
        messagesOpenAIFormatted = try container.decodeIfPresent([String].self, forKey: .messagesOpenAIFormatted)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(conversation, forKey: .conversation)
        try container.encodeIfPresent(messages, forKey: .messages)
        try container.encodeIfPresent(messagesOpenAIFormatted, forKey: .messagesOpenAIFormatted)
    }
}
