import SwiftUI
import LaunchDarklyObservability
import OpenTelemetryApi

struct InstrumentationView: View {
    var body: some View {
        VStack {
            TraceView()
            LogsView()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    InstrumentationView()
}
