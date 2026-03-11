//
//  VapiError.swift
//  
//
//  Created by Andrew Carter on 12/13/23.
//

import Foundation

public enum VapiError: Swift.Error, LocalizedError {
    case invalidURL
    case customError(String)
    case existingCallInProgress
    case noCallInProgress
    case decodingError(message: String, response: String? = nil)
    case invalidJsonData

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided is invalid."
        case .customError(let message):
            return message
        case .existingCallInProgress:
            return "A call is already in progress."
        case .noCallInProgress:
            return "No call is currently in progress."
        case .decodingError(let message, let response):
            if let response {
                return "Decoding error: \(message) — Response: \(response)"
            }
            return "Decoding error: \(message)"
        case .invalidJsonData:
            return "The JSON data is invalid."
        }
    }
}
