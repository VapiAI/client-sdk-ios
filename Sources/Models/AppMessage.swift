//
//  AppMessage.swift
//
//
//  Created by Brent Whitman on 2024-01-15.
//

import Foundation

public struct AppMessage: Codable {
    public enum MessageType: String, Codable {
        case transcript
    }
    
    public enum TranscriptType: String, Codable {
        case final
        case partial
    }
    
    public let type: MessageType
    public let role: String?
    public let transcriptType: TranscriptType?
    public let transcript: String?
}
