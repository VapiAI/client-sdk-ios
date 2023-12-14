import SwiftUI
import Vapi

struct CallView: View {
    @StateObject private var callManager = CallManager()

    var body: some View {
        VStack {
            if callManager.isOnCall {
                Text("In Call")
                Button("Hang Up", action: callManager.endCall)
            } else {
                Button("Start Call", action: callManager.startCall)
            }
        }
        .onAppear {
            callManager.setup()
        }
    }
}

class CallManager: ObservableObject {
    @Published var isOnCall = false
    private var vapi: Vapi?

    func setup() {
        let config = Vapi.Configuration(clientToken: "your_client_token")
        vapi = Vapi(configuration: config)

        vapi?.eventPublisher.sink { [weak self] event in
            switch event {
            case .callDidStart:
                self?.isOnCall = true
            case .callDidEnd:
                self?.isOnCall = false
            default:
                break
            }
        }.store(in: &cancellables)
    }

    func startCall() {
        do {
            try vapi?.start(assistantId: "your_assistant_id")
        } catch {
            print("Error starting call: \(error)")
        }
    }

    func endCall() {
        vapi?.stop()
    }
}
