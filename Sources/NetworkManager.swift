//
// Copyright (c) Vapi
//

import Foundation

class NetworkManager {
    
    private let session = URLSession(configuration: .default)
    
    func perform<T: Decodable>(request: URLRequest) async throws -> T {
        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw VapiError.networkFailure(underlying: error)
        }

        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            return result
        } catch {
            let responseString = String(data: data, encoding: .utf8)
            throw VapiError.decodingFailure(
                message: error.localizedDescription,
                response: responseString,
                underlying: error
            )
        }
    }
}
