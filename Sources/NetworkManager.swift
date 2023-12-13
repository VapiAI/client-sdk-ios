//
// Copyright (c) Vapi
//

import Foundation

class NetworkManager {
    static func performRequest<T: Decodable>(
        urlRequest: URLRequest,
        completion: @escaping (Result<T, VapiError>) -> Void
    ) {
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                guard let data = data else {
                    completion(.failure(.customError("No data received")))
                    return
                }
                do {
                    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decodedResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }.resume()
    }
}
