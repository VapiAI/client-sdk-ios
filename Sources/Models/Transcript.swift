//
//  Transcript.swift
//
//
//  Created by Brent Whitman on 2024-01-15.
//

import Foundation

public struct Transcript: Codable {
    public enum TranscriptType: String, Codable {
        case final
        case partial
    }
    
    public enum Role: String, Codable {
        case assistant
        case user
    }
    
    public let role: Role
    public let transcriptType: TranscriptType
    public let transcript: String
}


