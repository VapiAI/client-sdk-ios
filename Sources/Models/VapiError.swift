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
        case .customError(let message):
            return message
        case .decodingError(let message, let response):
            return response ?? message
        default:
            return String(describing: self)
        }
    }
}
