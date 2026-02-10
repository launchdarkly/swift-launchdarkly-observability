import SwiftUI
import LaunchDarklyObservability

struct InstrumentationView: View {
    var body: some View {
        VStack {
            TraceView()
            LogsView()
            Spacer()
        }
        .padding()
        .task {
            LDObserve.shared
                .start(
                    sessionId: "Custom-id:\(UUID().uuidString)"
                )
        }
    }
}

#Preview {
    InstrumentationView()
}
