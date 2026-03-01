//
//  AppMessage.swift
//  
//
//  Created by Brent Whitman on 2024-01-15.
//

import Foundation

struct AppMessage: Codable {
    enum MessageType: Codable, Equatable {
        case hang
        case functionCall
        case transcript
        case speechUpdate
        case metadata
        case conversationUpdate
        case modelOutput
        case statusUpdate
        case voiceInput
        case userInterrupted
        case assistantStarted
        case workflowNodeStarted
        case toolCalls
        case toolCallsResult
        case transferUpdate
        case languageChangeDetected
        case chatCreated
        case chatDeleted
        case sessionCreated
        case sessionUpdated
        case sessionDeleted
        case callDeleted
        case callDeleteFailed
        case unknown(String)

        private static let rawValueMapping: [(String, MessageType)] = [
            ("hang", .hang),
            ("function-call", .functionCall),
            ("transcript", .transcript),
            ("transcript[transcriptType=\"final\"]", .transcript),
            ("speech-update", .speechUpdate),
            ("metadata", .metadata),
            ("conversation-update", .conversationUpdate),
            ("model-output", .modelOutput),
            ("status-update", .statusUpdate),
            ("voice-input", .voiceInput),
            ("user-interrupted", .userInterrupted),
            ("assistant.started", .assistantStarted),
            ("workflow.node.started", .workflowNodeStarted),
            ("tool-calls", .toolCalls),
            ("tool-calls-result", .toolCallsResult),
            ("transfer-update", .transferUpdate),
            ("language-change-detected", .languageChangeDetected),
            ("chat.created", .chatCreated),
            ("chat.deleted", .chatDeleted),
            ("session.created", .sessionCreated),
            ("session.updated", .sessionUpdated),
            ("session.deleted", .sessionDeleted),
            ("call.deleted", .callDeleted),
            ("call.delete.failed", .callDeleteFailed),
        ]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = Self.rawValueMapping.first(where: { $0.0 == rawValue })?.1 ?? .unknown(rawValue)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .unknown(let rawValue):
                try container.encode(rawValue)
            default:
                if let pair = Self.rawValueMapping.first(where: { $0.1 == self }) {
                    try container.encode(pair.0)
                }
            }
        }
    }
    
    let type: MessageType
}
