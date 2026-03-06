//
//  VapiError.swift
//  
//
//  Created by Andrew Carter on 12/13/23.
//

import Foundation

public enum VapiError: Swift.Error {
    case invalidURL
    case urlConstructionFailed(host: String, path: String)
    case requestBodyEncodingFailed(underlying: Error)
    case networkFailure(underlying: Error)
    case webRTCFailure(operation: String, underlying: Error)
    case customError(String)
    case existingCallInProgress
    case noCallInProgress
    case decodingError(message: String, response: String? = nil)
    case decodingFailure(message: String, response: String? = nil, underlying: Error)
    case invalidJsonData
}

extension VapiError {
    public enum Code: String {
        case invalidURL
        case urlConstructionFailed
        case requestBodyEncodingFailed
        case networkFailure
        case webRTCFailure
        case customError
        case existingCallInProgress
        case noCallInProgress
        case decodingError
        case invalidJsonData
    }

    public var code: Code {
        switch self {
        case .invalidURL:
            return .invalidURL
        case .urlConstructionFailed:
            return .urlConstructionFailed
        case .requestBodyEncodingFailed:
            return .requestBodyEncodingFailed
        case .networkFailure:
            return .networkFailure
        case .webRTCFailure:
            return .webRTCFailure
        case .customError:
            return .customError
        case .existingCallInProgress:
            return .existingCallInProgress
        case .noCallInProgress:
            return .noCallInProgress
        case .decodingError,
             .decodingFailure:
            return .decodingError
        case .invalidJsonData:
            return .invalidJsonData
        }
    }

    public var underlyingError: Error? {
        switch self {
        case .requestBodyEncodingFailed(let underlying):
            return underlying
        case .networkFailure(let underlying):
            return underlying
        case .webRTCFailure(_, let underlying):
            return underlying
        case .decodingFailure(_, _, let underlying):
            return underlying
        case .invalidURL,
             .urlConstructionFailed,
             .customError,
             .existingCallInProgress,
             .noCallInProgress:
            return nil
        case .decodingError,
             .invalidJsonData:
            return nil
        }
    }
}

extension VapiError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .urlConstructionFailed(let host, let path):
            return "Failed to construct URL for host '\(host)' and path '\(path)'."
        case .requestBodyEncodingFailed:
            return "Failed to encode request body."
        case .networkFailure:
            return "Network request failed."
        case .webRTCFailure(let operation, _):
            return "WebRTC operation failed: \(operation)."
        case .customError(let message):
            return message
        case .existingCallInProgress:
            return "A call is already in progress."
        case .noCallInProgress:
            return "No call is currently in progress."
        case .decodingError(let message, _):
            return "Decoding error: \(message)"
        case .decodingFailure(let message, _, _):
            return "Decoding error: \(message)"
        case .invalidJsonData:
            return "Invalid JSON data."
        }
    }
}
