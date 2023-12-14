import UIKit
import Vapi

class CallViewController: UIViewController {
    private var vapi: Vapi?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupVapi()
    }

    private func setupVapi() {
        let config = Vapi.Configuration(clientToken: "your_client_token")
        vapi = Vapi(configuration: config)

        vapi?.eventPublisher.sink { [weak self] event in
            switch event {
            case .callDidStart:
                self?.updateUIForCallStart()
            case .callDidEnd:
                self?.updateUIForCallEnd()
            default:
                break
            }
        }.store(in: &cancellables)
    }

    @IBAction func startCallPressed(_ sender: UIButton) {
        do {
            try vapi?.start(assistantId: "your_assistant_id")
        } catch {
            print("Error starting call: \(error)")
        }
    }

    @IBAction func stopCallPressed(_ sender: UIButton) {
        vapi?.stop()
    }

    private func updateUIForCallStart() {
        // Update UI to show call has started
    }

    private func updateUIForCallEnd() {
        // Update UI to show call has ended
    }
}
