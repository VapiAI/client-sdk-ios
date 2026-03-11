//
// Copyright (c) Vapi
//

import Foundation

class NetworkManager {
    
    private let session = URLSession(configuration: .default)
    
    func perform<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, _) = try await session.data(for: request)
        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            return result
        } catch {
            let responseString = String(data: data, encoding: .utf8)
            throw VapiError.decodingError(message: Self.detailedErrorMessage(from: error), response: responseString)
        }
    }

    static func detailedErrorMessage(from error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return String(describing: error)
        }

        switch decodingError {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Type mismatch for \(type) at path '\(path)': \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Value not found for \(type) at path '\(path)': \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Key '\(key.stringValue)' not found at path '\(path)': \(context.debugDescription)"
        case .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Data corrupted at path '\(path)': \(context.debugDescription)"
        @unknown default:
            return String(describing: error)
        }
    }
}
