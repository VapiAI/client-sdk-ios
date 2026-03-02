//
//  AppMessage.swift
//  
//
//  Created by Brent Whitman on 2024-01-15.
//

import Foundation

struct AppMessage: Codable {
    enum MessageType: String, Codable {
        case hang
        case functionCall = "function-call"
        case transcript
        case transcriptFinal = "transcript[transcriptType=\"final\"]"
        case speechUpdate = "speech-update"
        case metadata
        case conversationUpdate = "conversation-update"
        case modelOutput = "model-output"
        case statusUpdate = "status-update"
        case voiceInput = "voice-input"
        case userInterrupted = "user-interrupted"
        case workflowNodeStarted = "workflow.node.started"
        case assistantStarted = "assistant.started"
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
    }
    
    let type: MessageType
}
