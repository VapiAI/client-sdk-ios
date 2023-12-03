import Foundation
import Daily

struct WebCallResponse: Decodable {
    let webCallUrl: String
}

// Define the delegate protocol
protocol VapiDelegate: AnyObject {
    func speechDidStart()
    func speechDidEnd()
    func callDidStart()
    func callDidEnd()
    func volumeLevelDidChange(volume: Int)
    func didEncounterError(error: Error)
}

public class Vapi: CallClientDelegate {
    private let clientToken: String
    weak var delegate: VapiDelegate?
    private var call: CallClient?

    public init(clientToken: String) {
        self.clientToken = clientToken
    }

    @MainActor
    private func joinCall(with url: URL) {
        Task.init {
            self.call = CallClient()
            self.call?.delegate = self
            do {
                try await self.call?.join(
                    url: url,
                    settings: .init(
                        inputs: .set(
                            camera: .set(.enabled(false)),
                            microphone: .set(.enabled(true))
                        )
                    )
                )
                self.callDidJoin()
            } catch {
                print("Error: \(error)")
                self.delegate?.didEncounterError(error: error as! Error)
            }
        }
    }

    @MainActor
    private func startCall(body: [String: Any]) {
        guard let url = URL(string: "https://api.vapi.ai/call/web") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(self.clientToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Error: \(error)")
                self.delegate?.didEncounterError(error: error as! Error)
            } else if let data = data {
                do {
                    let result = try JSONDecoder().decode(WebCallResponse.self, from: data)
                    if let url = URL(string: result.webCallUrl) {
                        self.joinCall(with: url)
                    } else {
                        print("Invalid webCallUrl")
                    }
                } catch {
                    print("Error: \(error)")
                    self.delegate?.didEncounterError(error: error as! Error)
                }
            }
        }
        task.resume()
    }

    @MainActor
    public func start(assistantId: String) {
      let body = ["assistantId": assistantId]
        self.startCall(body: body)
    }

    @MainActor
    public func start(assistant: [String: Any]) {
       let body = ["assistant": assistant]
       self.startCall(body: body)
    }

    public func stop() {
        // Stop the call
         Task.init {
            do {
                try await call?.leave()
                print("Successfully left call.")
                self.delegate?.callDidEnd()
            } catch {
                print("Got error while leaving call: \(error).")
                self.delegate?.didEncounterError(error: error as! Error)
            }
        }
    }

    // CallClientDelegate methods
    func callDidJoin() {
        print("Successfully joined call.")
        self.delegate?.callDidStart()
    }

    func callDidLeave() {
        print("Successfully left call.")
        self.delegate?.callDidEnd()
    }

    func callDidFail(with error: Error) {
        print("Got error while joining/leaving call: \(error).")
        self.delegate?.didEncounterError(error: error)
    }
}
