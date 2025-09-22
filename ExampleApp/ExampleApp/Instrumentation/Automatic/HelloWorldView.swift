import SwiftUI
import ObservabilitySwiftUIExtensions

struct AChildView: View {
    @State private var count = 0
    var body: some View {
        VStack {
            Text("Child A View")
                .padding()
            Text(count.description)
                .bold()
            Button {
                count = count + 1
            } label: {
                Text("Increment")
                    .bold()
            }
            .tint(.yellow)
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background {
            Color.red
        }
    }
}

struct HelloWorldView: View {
    @State private var count = 0
    var body: some View {
        VStack {
            Text(count.description)
                .bold()
            Button {
                count = count + 1
            } label: {
                Text("Increment")
            }
            AChildView()
        }
        .logScreenName(
            "HelloWorldView",
            attributes: [
                "view": .string("vstack")
            ]
        )
        .onAppear {
            print("PRINT FROM ONAPPEAR")
        }
    }
}

#Preview {
    HelloWorldView()
}
