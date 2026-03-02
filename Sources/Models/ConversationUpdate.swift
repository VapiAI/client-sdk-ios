import Foundation

public struct Message: Codable {
    public enum Role: String, Codable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
        case tool = "tool"
        case unknown

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = Role(rawValue: rawValue) ?? .unknown
        }
    }
    
    public let role: Role
    public let content: String?

    private enum CodingKeys: String, CodingKey {
        case role
        case content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = (try? container.decode(Role.self, forKey: .role)) ?? .unknown
        content = try? container.decodeIfPresent(String.self, forKey: .content)
    }
}

public struct ConversationUpdate: Codable {
    public let conversation: [Message]

    private enum CodingKeys: String, CodingKey {
        case conversation
        case messages
        case messagesOpenAIFormatted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let conversation = try? container.decode([Message].self, forKey: .conversation) {
            self.conversation = conversation
            return
        }

        if let messages = try? container.decode([Message].self, forKey: .messages) {
            self.conversation = messages
            return
        }

        if let openAIFormattedMessages = try? container.decode([Message].self, forKey: .messagesOpenAIFormatted) {
            self.conversation = openAIFormattedMessages
            return
        }

        self.conversation = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(conversation, forKey: .conversation)
    }
}
