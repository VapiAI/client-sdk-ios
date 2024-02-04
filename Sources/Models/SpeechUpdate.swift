import Foundation

public struct SpeechUpdate: Codable {
    public enum Status: String, Codable {
        case started
        case stopped
    }
    
    public enum Role: String, Codable {
        case assistant
        case user
    }
    
    public let status: Status
    public let role: Role
}
