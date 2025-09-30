import SwiftUI

struct NetworkRequestView: View {
    @State private var loading = false
    var body: some View {
        Group {
            if loading {
                ProgressView {
                    Text("Loading content that will be instrumented")
                }
            } else {
                Text("Check the LaunchDarkly dashboard for instrumentation")
            }
        }
        .task {
            guard let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1") else { return }
            do {
                let (_, _) = try await URLSession.shared.data(from: url)
            } catch {
                
            }
        }
        .task {
            guard let url = URL(string: "http://localhost/something") else { return }
            do {
                let (_, _) = try await URLSession.shared.data(from: url)
            } catch {
                
            }
        }
    }
}
