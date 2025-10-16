import SwiftUI
import LaunchDarklyObservability

enum SampleError: Error, LocalizedError {
    case error1
    case error2
    
    var errorDescription: String? {
        switch self {
        case .error1:
            return "Something wrong happened, this is error1"
        case .error2:
            return "Something wrong happened, this is error2"
        }
    }
}

struct TraceView: View {
    @State private var name: String = ""
    @State private var started = false
    @State private var span = Optional<Span>.none
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Traces")
                .bold()
            HStack {
                TextField(text: $name) {
                    Text("Span name:")
                }
                .autocorrectionDisabled(true)
                .textCase(.lowercase)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
                Spacer()
                Text("is started")
                Toggle(isOn: $started) {
                    Text("started")
                }
                .labelsHidden()
                .disabled(name.isEmpty)
                .task(id: started) {
                    guard started else {
                        span?.end()
                        _ = LDObserve.shared.flush()
                        return name = ""
                    }
                    span = LDObserve.shared.startSpan(name: name, attributes: [:])
                }
            }
            Divider()
            VStack(spacing: 16.0) {
                Button {
                    LDObserve.shared.recordError(
                        error: SampleError.error1,
                        attributes: [:]
                    )
                } label: {
                    Text("Throw Error 1")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    LDObserve.shared.recordError(
                        error: SampleError.error2,
                        attributes: [:]
                    )
                } label: {
                    Text("Throw Error 2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            Divider()
        }
    }
}
