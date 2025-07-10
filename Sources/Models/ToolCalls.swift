//
//  ToolCalls.swift
//
//
//  Created by Anton Begehr on 2025-07-10.
//

import Foundation

public struct ToolCalls: Codable {
    public let toolCalls: [ToolCall]
}

public struct ToolCall: Codable {
    enum CodingKeys: CodingKey {
        case id
        case type
        case function
    }
    
    public let id: String
    public let type: String
    public let function: Function
}

public extension ToolCall {
    struct Function: Codable {
        enum CodingKeys: CodingKey {
            case name
            case arguments
        }

        public let name: String
        public let arguments: AnyCodable // In `conversation-update`, this will be an encoded string. In `tool-calls`, this will be a dictionary.
    }
}
