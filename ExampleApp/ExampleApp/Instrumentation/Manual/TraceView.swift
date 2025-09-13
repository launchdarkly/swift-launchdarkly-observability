import SwiftUI
import LaunchDarklyObservability
import OpenTelemetryApi


struct TraceView: View {
    @State private var name: String = ""
    @State private var started = false
    @State private var span = Optional<Span>.none
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Traces")
                .bold()
            HStack {
                TextField(text: $name) {
                    Text("Span name:")
                }
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
                        return name = ""
                    }
                    span = LDObserve.shared.startSpan(name: name)
                }
            }
        }
    }
}
