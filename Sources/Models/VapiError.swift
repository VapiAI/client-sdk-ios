//
//  VapiError.swift
//  
//
//  Created by Andrew Carter on 12/13/23.
//

import Foundation

public enum VapiError: LocalizedError {
    case invalidURL
    case customError(String)
    case existingCallInProgress
    case noCallInProgress
    case decodingError(message: String, response: String? = nil)
    case invalidJsonData
}

extension VapiError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL is invalid"
        case .customError(let message):
            return message
        case .existingCallInProgress:
            return "An existing call is in progress"
        case .noCallInProgress:
            return "No call in progress"
        case .decodingError(let message, let response):
            return "\(message)\n\(response ?? "No response data")"
        case .invalidJsonData:
            return "Invalid JSON data"
        }
    }
}
