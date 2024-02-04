import Foundation

public struct Metadata: Codable {
    public enum MessageType: String, Codable {
        case metadata = "metadata"
    }
    
    public let type: MessageType
    public let metadata: String
}
