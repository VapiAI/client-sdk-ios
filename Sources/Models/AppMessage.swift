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
    }
    
    let type: MessageType
}
