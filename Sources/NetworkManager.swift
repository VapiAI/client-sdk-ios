//
// Copyright (c) Vapi
//

import Foundation

class NetworkManager {

    private let session = URLSession(configuration: .default)

    func perform<T: Decodable>(request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            VapiLogger.log(
                level: .error,
                component: .network,
                message: "Network request failed",
                context: [
                    "url": request.url?.absoluteString ?? "nil",
                    "error": String(describing: error)
                ]
            )
            throw VapiError.networkError(underlyingError: error, url: request.url)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let responseBody = String(data: data, encoding: .utf8)
            VapiLogger.log(
                level: .error,
                component: .network,
                message: "HTTP error response",
                context: [
                    "url": request.url?.absoluteString ?? "nil",
                    "statusCode": String(httpResponse.statusCode),
                    "responseBody": responseBody ?? "<non-UTF8>"
                ]
            )
            throw VapiError.httpError(
                statusCode: httpResponse.statusCode,
                responseBody: responseBody,
                url: request.url
            )
        }

        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            return result
        } catch {
            let responseBody = String(data: data, encoding: .utf8)
            VapiLogger.log(
                level: .error,
                component: .network,
                message: "Response decoding failed",
                context: [
                    "url": request.url?.absoluteString ?? "nil",
                    "decodingError": String(describing: error),
                    "responseBody": responseBody ?? "<non-UTF8>"
                ]
            )
            throw VapiError.responseDecoding(underlyingError: error, responseBody: responseBody)
        }
    }
}
