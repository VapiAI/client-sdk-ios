//
// Copyright (c) Vapi
//

import Foundation

class NetworkManager {
    
    private let session = URLSession(configuration: .default)
    
    func perform<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, _) = try await session.data(for: request)
        let result = try JSONDecoder().decode(T.self, from: data)
        return result
    }
}
