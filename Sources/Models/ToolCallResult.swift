import Foundation

public struct ToolCallResult: Codable {
    public let toolCallResult: [String: AnyCodable]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolCallResult = (try? container.decode([String: AnyCodable].self, forKey: .toolCallResult)) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case toolCallResult
    }
}
