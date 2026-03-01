import Foundation

public struct TransferDestination: Codable {
    public let type: String?
    public let message: String?
    public let description: String?
}

public struct TransferUpdate: Codable {
    public let destination: TransferDestination?
    public let toAssistant: [String: AnyCodable]?
    public let fromAssistant: [String: AnyCodable]?
    public let toStepRecord: [String: AnyCodable]?
    public let fromStepRecord: [String: AnyCodable]?
}
