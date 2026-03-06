import XCTest
@testable import Vapi

final class VapiTests: XCTestCase {
    func testErrorCodesForNewFailureTypes() throws {
        let networkError = VapiError.networkFailure(underlying: URLError(.timedOut))
        XCTAssertEqual(networkError.code, .networkFailure)

        let webRTCError = VapiError.webRTCFailure(operation: "joinCall.joinOrStartRecording", underlying: URLError(.cannotConnectToHost))
        XCTAssertEqual(webRTCError.code, .webRTCFailure)

        let urlError = VapiError.urlConstructionFailed(host: "bad host", path: "/call/web")
        XCTAssertEqual(urlError.code, .urlConstructionFailed)
    }

    func testUnderlyingErrorIsPreserved() throws {
        let underlying = URLError(.timedOut)
        let error = VapiError.networkFailure(underlying: underlying)

        guard let resolvedUnderlying = error.underlyingError as? URLError else {
            return XCTFail("Expected URLError as underlying error")
        }

        XCTAssertEqual(resolvedUnderlying.code, underlying.code)
    }
}
