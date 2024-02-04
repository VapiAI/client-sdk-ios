import Foundation

public struct Message: Codable {
    public enum Role: String, Codable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
    }
    
    public let role: Role
    public let content: String
}

public struct ConversationUpdate: Codable {
    public let conversation: [Message]
}
