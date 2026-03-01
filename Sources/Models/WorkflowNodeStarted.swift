import Foundation

public struct WorkflowNodeStarted: Codable {
    public let node: [String: AnyCodable]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        node = (try? container.decode([String: AnyCodable].self, forKey: .node)) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case node
    }
}
