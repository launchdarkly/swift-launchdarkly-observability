#if os(iOS)
import SwiftUI

struct DialogsSwiftUIView: View {
    @Environment(\.dismiss) var dismiss

    @State private var showAlert = false
    @State private var showConfirmation = false
    @State private var showHalfSheet = false
    @State private var showFullSheet = false
    @State private var showFullScreenCover = false
    @State private var showOverlay = false
    @State private var windowPresenter = WindowSheetPresenter()

    var body: some View {
        NavigationStack {
            List {
                Section("Alerts") {
                    Button("Simple Alert") { showAlert = true }
                    Button("Confirmation Dialog") { showConfirmation = true }
                }

                Section("Bottom Sheets") {
                    Button("Half Sheet") { showHalfSheet = true }
                    Button("Full Sheet") { showFullSheet = true }
                    Button("Full Screen Cover") { showFullScreenCover = true }
                    Button("UIWindow Sheet") { presentWindowSheet() }
                }

                Section("Overlay") {
                    Button("View Overlay") { showOverlay = true }
                }
            }
            .navigationTitle("Dialogs (SwiftUI)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button { dismiss() } label: { Image(systemName: "xmark") }
            }
            .alert("Alert", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This is an example alert dialog.")
            }
            .confirmationDialog("Actions", isPresented: $showConfirmation, titleVisibility: .visible) {
                Button("Option A") { }
                Button("Option B") { }
                Button("Delete", role: .destructive) { }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showHalfSheet) {
                DialogsCountdownSheet(title: "Half Sheet")
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showFullSheet) {
                DialogsCountdownSheet(title: "Full Sheet")
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $showFullScreenCover) {
                DialogsCountdownSheet(title: "Full Screen Cover")
            }
            .overlay {
                if showOverlay {
                    DialogsCountdownOverlay {
                        showOverlay = false
                    }
                }
            }
        }
    }

    private func presentWindowSheet() {
        windowPresenter.present(
            content: DialogsCountdownOverlay {
                windowPresenter.dismiss()
            }
        )
    }
}

private struct DialogsCountdownSheet: View {
    let title: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text(title)
                    .font(.headline)
                    .padding(.top)
                CountdownTimerView {
                    dismiss()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }
}

private struct DialogsCountdownOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack {
                CountdownTimerView {
                    onDismiss()
                }
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
#endif
