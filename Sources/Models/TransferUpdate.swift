import Foundation

public struct TransferUpdate: Codable {
    public let destination: JSONValue?
    public let toAssistant: JSONValue?
    public let fromAssistant: JSONValue?
    public let toStepRecord: JSONValue?
    public let fromStepRecord: JSONValue?
}
