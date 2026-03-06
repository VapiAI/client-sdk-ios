//
//  VapiError.swift
//
//
//  Created by Andrew Carter on 12/13/23.
//

import Foundation

public enum VapiError: Swift.Error, LocalizedError {

    // MARK: - Specific Error Cases

    /// URL construction failed for the given host and path.
    case urlConstruction(host: String, path: String)

    /// The request body could not be serialized to JSON.
    case requestBodyEncoding(underlyingError: Swift.Error)

    /// A network-level error occurred (DNS, connectivity, timeout, TLS, etc.).
    case networkError(underlyingError: Swift.Error, url: URL?)

    /// The server returned a non-2xx HTTP status code.
    case httpError(statusCode: Int, responseBody: String?, url: URL?)

    /// The server response could not be decoded into the expected model.
    case responseDecoding(underlyingError: Swift.Error, responseBody: String?)

    /// A WebRTC (Daily) operation failed.
    case webRTCError(underlyingError: Swift.Error, operation: String)

    // MARK: - Call State Errors

    /// A call is already in progress; cannot start a new one.
    case existingCallInProgress

    /// No call is currently in progress.
    case noCallInProgress

    // MARK: - Legacy Cases (backward compatibility)

    case invalidURL
    case customError(String)
    case decodingError(message: String, response: String? = nil)
    case invalidJsonData

    // MARK: - Underlying Error Access

    /// Returns the original error that caused this failure, if one exists.
    public var underlyingError: Swift.Error? {
        switch self {
        case .requestBodyEncoding(let error):       return error
        case .networkError(let error, _):           return error
        case .responseDecoding(let error, _):       return error
        case .webRTCError(let error, _):            return error
        default:                                    return nil
        }
    }

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .urlConstruction(let host, let path):
            return "Failed to construct URL for host '\(host)' with path '\(path)'"
        case .requestBodyEncoding(let error):
            return "Failed to encode request body: \(error.localizedDescription)"
        case .networkError(let error, let url):
            let urlString = url?.absoluteString ?? "unknown"
            return "Network request to '\(urlString)' failed: \(error.localizedDescription)"
        case .httpError(let statusCode, _, let url):
            let urlString = url?.absoluteString ?? "unknown"
            return "HTTP \(statusCode) error from '\(urlString)'"
        case .responseDecoding(let error, _):
            return "Failed to decode server response: \(error.localizedDescription)"
        case .webRTCError(let error, let operation):
            return "WebRTC operation '\(operation)' failed: \(error.localizedDescription)"
        case .existingCallInProgress:
            return "A call is already in progress"
        case .noCallInProgress:
            return "No call is currently in progress"
        case .invalidURL:
            return "The URL is invalid"
        case .customError(let message):
            return message
        case .decodingError(let message, _):
            return "Decoding error: \(message)"
        case .invalidJsonData:
            return "Invalid JSON data"
        }
    }
}
