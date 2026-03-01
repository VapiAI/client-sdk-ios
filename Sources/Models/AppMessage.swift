//
//  AppMessage.swift
//  
//
//  Created by Brent Whitman on 2024-01-15.
//

import Foundation

struct AppMessage: Decodable {
    enum MessageType: String {
        case hang
        case functionCall = "function-call"
        case transcript
        case speechUpdate = "speech-update"
        case metadata
        case conversationUpdate = "conversation-update"
        case modelOutput = "model-output"
        case statusUpdate = "status-update"
        case voiceInput = "voice-input"
        case userInterrupted = "user-interrupted"
        case assistantStarted = "assistant.started"
        case workflowNodeStarted = "workflow.node.started"
        case toolCalls = "tool-calls"
        case toolCallsResult = "tool-calls-result"
        case transferUpdate = "transfer-update"
        case languageChangeDetected = "language-change-detected"
        case chatCreated = "chat.created"
        case chatDeleted = "chat.deleted"
        case sessionCreated = "session.created"
        case sessionUpdated = "session.updated"
        case sessionDeleted = "session.deleted"
        case callDeleted = "call.deleted"
        case callDeleteFailed = "call.delete.failed"
        case unknown
    }

    let type: String

    var messageType: MessageType {
        // Messages can be configured as transcript[transcriptType="final"].
        let normalizedType = String(type.split(separator: "[", maxSplits: 1).first ?? "")

        switch normalizedType {
        case MessageType.functionCall.rawValue:
            return .functionCall
        case MessageType.hang.rawValue:
            return .hang
        case MessageType.transcript.rawValue:
            return .transcript
        case MessageType.speechUpdate.rawValue:
            return .speechUpdate
        case MessageType.metadata.rawValue:
            return .metadata
        case MessageType.conversationUpdate.rawValue:
            return .conversationUpdate
        case MessageType.modelOutput.rawValue:
            return .modelOutput
        case MessageType.statusUpdate.rawValue:
            return .statusUpdate
        case MessageType.voiceInput.rawValue:
            return .voiceInput
        case MessageType.userInterrupted.rawValue:
            return .userInterrupted
        case MessageType.assistantStarted.rawValue:
            return .assistantStarted
        case MessageType.workflowNodeStarted.rawValue:
            return .workflowNodeStarted
        case MessageType.toolCalls.rawValue:
            return .toolCalls
        case MessageType.toolCallsResult.rawValue, "function-call-result", "tool.completed", "assistant.tool.completed":
            return .toolCallsResult
        case MessageType.transferUpdate.rawValue:
            return .transferUpdate
        case MessageType.languageChangeDetected.rawValue, "language-changed":
            return .languageChangeDetected
        case MessageType.chatCreated.rawValue:
            return .chatCreated
        case MessageType.chatDeleted.rawValue:
            return .chatDeleted
        case MessageType.sessionCreated.rawValue:
            return .sessionCreated
        case MessageType.sessionUpdated.rawValue:
            return .sessionUpdated
        case MessageType.sessionDeleted.rawValue:
            return .sessionDeleted
        case MessageType.callDeleted.rawValue:
            return .callDeleted
        case MessageType.callDeleteFailed.rawValue:
            return .callDeleteFailed
        default:
            return .unknown
        }
    }
}
