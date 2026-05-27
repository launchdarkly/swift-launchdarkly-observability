import SwiftUI
import LaunchDarklySessionReplay

struct NestedMaskingPropagationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var baselineText = ""
    @State private var unmaskedText = ""
    @State private var maskedText = ""
    @State private var deepText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section(title: "1. Baseline (no modifier)",
                            note: "Globally masked by maskTextInputs.") {
                        TextField("type here", text: $baselineText)
                            .textFieldStyle(.roundedBorder)
                    }

                    section(title: "2. Ancestor .ldUnmask()",
                            note: "Parent VStack is unmasked — child TextField should be visible despite maskTextInputs=true.") {
                        VStack(alignment: .leading) {
                            TextField("visible inside unmasked ancestor", text: $unmaskedText)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.15))
                        .ldUnmask()
                    }

                    section(title: "3. Ancestor .ldMask()",
                            note: "Parent VStack is masked — all children get covered, even the plain Text label.") {
                        VStack(alignment: .leading) {
                            Text("plain label that would normally be visible")
                            TextField("textfield inside masked ancestor", text: $maskedText)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.15))
                        .ldMask()
                    }

                    section(title: "4. Deep unmask through nesting",
                            note: "Two levels of nesting under .ldUnmask() — propagation should still apply.") {
                        VStack(alignment: .leading) {
                            VStack(alignment: .leading) {
                                TextField("deeply nested, still unmasked", text: $deepText)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.05))
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.15))
                        .ldUnmask()
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Ancestor Mask Propagation")
            .toolbar {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                }
                SnapshotButton()
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, note: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(note).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }
}

#Preview {
    NestedMaskingPropagationView()
}
