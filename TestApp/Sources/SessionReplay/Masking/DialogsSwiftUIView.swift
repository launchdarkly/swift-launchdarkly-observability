#if os(iOS)
import SwiftUI

struct DialogsSwiftUIView: View {
    @Environment(\.dismiss) var dismiss

    @State private var showAlert = false
    @State private var showConfirmation = false
    @State private var showFullSheet = false
    @State private var showFullScreenCover = false
    @State private var showOverlay = false
    @State private var activeHalfSheetSizing: DimSizing?
    @State private var windowPresenter = WindowSheetPresenter()

    var body: some View {
        NavigationStack {
            List {
                Section("Alerts") {
                    Button("Simple Alert") { showAlert = true }
                    Button("Confirmation Dialog") { showConfirmation = true }
                }

                Section("Bottom Sheets") {
                    Button("Full Sheet") { showFullSheet = true }
                    Button("Full Screen Cover") { showFullScreenCover = true }
                }

                Section("Half Sheet") {
                    HStack(spacing: 6) {
                        ForEach(DimSizing.allCases, id: \.self) { sizing in
                            Button(sizing.rawValue) { activeHalfSheetSizing = sizing }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                }

                Section("UIWindow Sizing") {
                    HStack(spacing: 6) {
                        ForEach(DimSizing.allCases, id: \.self) { sizing in
                            Button(sizing.rawValue) { presentWindowSheet(sizing: sizing) }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
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
            .sheet(isPresented: $showFullSheet) {
                DialogsCountdownSheet(title: "Full Sheet")
                    .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $showFullScreenCover) {
                DialogsCountdownSheet(title: "Full Screen Cover")
            }
            .overlay {
                if let sizing = activeHalfSheetSizing {
                    DialogsHalfSheetOverlay(sizing: sizing) {
                        activeHalfSheetSizing = nil
                    }
                }
            }
            .overlay {
                if showOverlay {
                    DialogsCountdownOverlay(sizing: .bounded) {
                        showOverlay = false
                    }
                }
            }
        }
    }

    private func presentWindowSheet(sizing: DimSizing) {
        windowPresenter.present(
            content: DialogsHalfSheetOverlay(sizing: sizing) {
                windowPresenter.dismiss()
            }
        )
    }
}

// MARK: - Countdown sheet (full sheet / full screen cover)

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

// MARK: - Half sheet overlay with parameterized dim sizing

private struct DialogsHalfSheetOverlay: View {
    let sizing: DimSizing
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geo in
            let screen = geo.size
            let frame = sizing.dimFrame(for: CGRect(origin: .zero, size: screen))

            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.4)
                    .onTapGesture { onDismiss() }

                VStack {
                    CountdownTimerView { onDismiss() }
                }
                .frame(width: screen.width, height: screen.height * 0.5)
                .background(.regularMaterial)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
                .offset(
                    x: -frame.origin.x,
                    y: -frame.origin.y + screen.height * 0.5
                )
            }
            .frame(width: frame.width, height: frame.height)
            .position(
                x: frame.origin.x + frame.width / 2,
                y: frame.origin.y + frame.height / 2
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Centered overlay (for View Overlay button)

private struct DialogsCountdownOverlay: View {
    let sizing: DimSizing
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                let frame = sizing.dimFrame(for: CGRect(origin: .zero, size: geo.size))
                Color.black.opacity(0.4)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .onTapGesture { onDismiss() }

                VStack {
                    CountdownTimerView { onDismiss() }
                }
                .padding(32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .ignoresSafeArea()
    }
}
#endif
