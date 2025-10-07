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
    }
}

#Preview {
    InstrumentationView()
}
