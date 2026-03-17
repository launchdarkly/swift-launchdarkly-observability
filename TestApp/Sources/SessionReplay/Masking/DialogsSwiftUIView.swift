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
                    DialogsHalfSheetOverlay(title: "Half Sheet · \(sizing.rawValue)", sizing: sizing) {
                        activeHalfSheetSizing = nil
                    }
                }
            }
            .overlay {
                if showOverlay {
                    DialogsCountdownOverlay(title: "View Overlay", sizing: .bounded) {
                        showOverlay = false
                    }
                }
            }
        }
    }

    private func presentWindowSheet(sizing: DimSizing) {
        let screenBounds = UIScreen.main.bounds
        let windowFrame = sizing.dimFrame(for: screenBounds)
        windowPresenter.present(
            content: DialogsWindowContent(
                title: "UIWindow · \(sizing.rawValue)",
                sizing: sizing,
                screenSize: screenBounds.size,
                onDismiss: { windowPresenter.dismiss() }
            ),
            windowFrame: windowFrame
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
                CountdownTimerView(title: title) {
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

// MARK: - Half sheet overlay backed by an oversized UIView

private struct DialogsHalfSheetOverlay: UIViewRepresentable {
    let title: String
    let sizing: DimSizing
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIView(context: Context) -> UIView {
        let wrapper = UIView()
        wrapper.clipsToBounds = false
        wrapper.backgroundColor = .clear

        let screenBounds = UIScreen.main.bounds
        let oversizedFrame = sizing.dimFrame(for: screenBounds)

        let container = UIView(frame: oversizedFrame)
        container.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        container.addGestureRecognizer(tap)

        let timerView = CountdownTimerView(title: title) { context.coordinator.handleTap() }
        let hosting = UIHostingController(rootView: timerView)
        hosting.view.backgroundColor = .systemBackground
        hosting.view.layer.cornerRadius = 16
        hosting.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        hosting.view.clipsToBounds = true
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.retainedController = hosting

        container.addSubview(hosting.view)

        let visibleX = -oversizedFrame.origin.x
        let visibleY = -oversizedFrame.origin.y

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: visibleX),
            hosting.view.widthAnchor.constraint(equalToConstant: screenBounds.width),
            hosting.view.topAnchor.constraint(equalTo: container.topAnchor, constant: visibleY + screenBounds.height / 2),
            hosting.view.heightAnchor.constraint(equalToConstant: screenBounds.height / 2),
        ])

        wrapper.addSubview(container)
        return wrapper
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Coordinator: NSObject {
        let onDismiss: () -> Void
        var retainedController: UIViewController?

        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        @objc func handleTap() { onDismiss() }
    }
}

// MARK: - Window overlay content (fills an oversized UIWindow)

private struct DialogsWindowContent: View {
    let title: String
    let sizing: DimSizing
    let screenSize: CGSize
    let onDismiss: () -> Void

    var body: some View {
        let frame = sizing.dimFrame(for: CGRect(origin: .zero, size: screenSize))

        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.4)
                .onTapGesture { onDismiss() }

            VStack {
                CountdownTimerView(title: title) { onDismiss() }
            }
            .frame(width: screenSize.width, height: screenSize.height * 0.5)
            .background(.regularMaterial)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
            .offset(
                x: -frame.origin.x,
                y: -frame.origin.y + screenSize.height * 0.5
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Centered overlay (for View Overlay button)

private struct DialogsCountdownOverlay: View {
    let title: String
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
                    CountdownTimerView(title: title) { onDismiss() }
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
