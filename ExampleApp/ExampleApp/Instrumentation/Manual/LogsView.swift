import SwiftUI
import LaunchDarklyObservability


struct LogsView: View {
    @State private var message: String = ""
    @State private var pressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Logs")
                .bold()
            HStack {
                TextField(text: $message) {
                    Text("Message:")
                }
                .autocorrectionDisabled(true)
                .textCase(.lowercase)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
                Spacer()
                Button {
                    pressed.toggle()
                } label: {
                    if pressed {
                        ProgressView {
                            Text("...")
                        }
                    } else {
                        Text("Log button pressed")
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("logsView-send-button")
                .disabled(message.isEmpty)
                .task(id: pressed) {
                    guard pressed else {
                        return
                    }
                    LDObserve.shared.recordLog(
                        message: message,
                        severity: .info,
                        attributes: [
                            "user_id": .string("1234"),
                            "action": .string("logsView-send-button-pressed")
                        ]
                    )
                    pressed.toggle()
                    message = ""
                }
            }
        }
    }
}
