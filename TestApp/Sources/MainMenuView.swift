import SwiftUI
import LaunchDarklyObservability
import LaunchDarklySessionReplay
import LaunchDarkly

enum Failure: LocalizedError {
    case test
    case crash
    
    var errorDescription: String? {
        switch self {
        case .test:
            return "this is a test error"
        case .crash:
            return "this is a crash error"
        }
    }
}

struct MainMenuView: View {
    @StateObject private var viewModel = MainMenuViewModel()
    @State private var path: [String] = []
    /// Single source of truth for the presented sheet. `nil` means none — so tracking back to
    /// "Main Menu" on dismissal is just `activeSheet != nil`.
    @State private var activeSheet: MenuSheet?
    @State private var isSessionReplayEnabled: Bool = true

    @ViewBuilder
    private func sheetContent(_ sheet: MenuSheet) -> some View {
        switch sheet {
        case .maskingOneFieldUIKit: MaskingElementsSimpleUIKitView()
        case .maskPropagationSwiftUI: NestedMaskingPropagationView()
        case .maskPropagationUIKit: NestedMaskingPropagationUIKitView()
        case .numberPad: NumberPadView()
        case .storyboard: StoryboardRootView()
        #if os(iOS)
        case .creditCardUIKit: MaskingCreditCardUIKitView()
        case .creditCardSwiftUI: MaskingCreditCardSwiftUIView()
        case .notebook: NotebookView()
        case .dialogsUIKit: DialogsUIKitView()
        case .dialogsSwiftUI: DialogsSwiftUIView()
        #endif
        #if canImport(WebKit)
        case .webView: WebViewControllertView()
        #endif
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            HStack {
                Image("Logo")
                Text("LaunchDarkly Observability \(Date().formatted(.dateTime.hour().minute().second()))")
            }
            
            List {
                sessionReplaySection
                observabilitySection
            }
            .environment(\.defaultMinListRowHeight, 0)
            #if !os(tvOS)
            .listRowSpacing(0)
            #endif
            .background(Color.clear)
            .navigationDestination(for: String.self) { value in
                switch value {
                #if os(iOS)
                case "fruta":
                    FrutaAppView()
                #endif
                default:
                    EmptyView()
                }
            }
        }
        // Path-driven tracking so popping back to the root re-emits "Main Menu" (SwiftUI does not
        // re-run `.onAppear` on pop). "fruta" tracks itself via its own screens, so skip it here.
        .trackScreenStack(path, root: "Main Menu") { $0 == "fruta" ? nil : $0 }
        // Re-emit "Main Menu" when the presented sheet is dismissed (SwiftUI does not re-run the
        // presenter's `.onAppear` after a sheet closes).
        .trackScreenReturn("Main Menu", isPresented: activeSheet != nil)
        #if os(iOS)
        .onChange(of: path) { newValue in
            if !newValue.contains("fruta") {
                if AppTabNavigation.pullPushLoop > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.9...1.1)) {
                        path.append("fruta")
                    }
                }
            }
        }
        #endif
        .sheet(item: $activeSheet) { sheet in
            sheetContent(sheet)
        }
    }

    // MARK: - Session Replay

    private var sessionReplaySection: some View {
        Section {
            MaskingGridRow(title: "One TextField", uikitAction: {
                activeSheet = .maskingOneFieldUIKit
            }, swiftUIAction: nil).ldMask()

#if os(iOS)
            MaskingGridRow(title: "Credit Card", uikitAction: {
                activeSheet = .creditCardUIKit
            }) {
                activeSheet = .creditCardSwiftUI
            }
            MaskingGridRow(title: "Number Pad", uikitAction: nil) {
                activeSheet = .numberPad
            }
            MaskingGridRow(title: "Mask Propagation", uikitAction: {
                activeSheet = .maskPropagationUIKit
            }) {
                activeSheet = .maskPropagationSwiftUI
            }
            MaskingGridRow(title: "Dialogs", uikitAction: {
                activeSheet = .dialogsUIKit
            }) {
                activeSheet = .dialogsSwiftUI
            }
#endif
#if os(iOS)
            MaskingGridRow(title: "Fruta", uikitAction: nil) {
                path.append("fruta")
            }
#endif
            HStack {
#if os(iOS)
                Button("Drawing") {
                    activeSheet = .notebook
                }
                .buttonStyle(.borderedProminent)
#endif

                Button("Storyboard") {
                    activeSheet = .storyboard
                }
                .buttonStyle(.borderedProminent)
#if canImport(WebKit)
                Button("WebView") {
                    activeSheet = .webView
                }
                .buttonStyle(.borderedProminent)
#endif
            }
        } header: {
            HStack {
                Text("Session Replay")
                Spacer()
                Toggle("", isOn: $isSessionReplayEnabled)
                    .labelsHidden()
                    .onChange(of: isSessionReplayEnabled) { enabled in
                        if enabled {
                            LDReplay.shared.start()
                        } else {
                            LDReplay.shared.stop()
                        }
                    }
            }
        }
    }

    // MARK: - Observability

    private var observabilitySection: some View {
        Section("Observability") {
            Text("Identify")
                .fontWeight(.bold)

            HStack {
                Button {
                    viewModel.identifyUser()
                } label: {
                    Text("User").foregroundStyle(Colors.identifyTextColor)
                }
                .buttonStyle(.borderedProminent)
                .tint(Colors.identifyBgColor)

                Button {
                    viewModel.identifyMulti()
                } label: {
                    Text("Multi").foregroundStyle(Colors.identifyTextColor)
                }
                .buttonStyle(.borderedProminent)
                .tint(Colors.identifyBgColor)

                Button {
                    viewModel.identifyAnonymous()
                } label: {
                    Text("Anon").foregroundStyle(Colors.identifyTextColor)
                }
                .buttonStyle(.borderedProminent)
                .tint(Colors.identifyBgColor)
            }

            Text("Instrumentation")
                .fontWeight(.bold)

            HStack {
                Button {
                    Task {
                        await viewModel.performNetworkRequest()
                    }
                } label: {
                    if viewModel.isNetworkInProgress {
                        ProgressView {
                            Text("get request to launchdarkly.com...")
                        }
                    } else {
                        Text("Network Request")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isNetworkInProgress)

                Button {
                    viewModel.crash()
                } label: {
                    Text("Crash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

#if os(iOS)
            NavigationLink(destination: SystemUnderPressureView()) {
                Text("Simulate System Under Pressure")
            }
#endif

            Text("Metric")
                .fontWeight(.bold)

            HStack {
                Button("Metric") { viewModel.recordMetric() }
                    .buttonStyle(.borderedProminent)
                Button("Histogram") { viewModel.recordHistogramMetric() }
                    .buttonStyle(.borderedProminent)
                Button("Count") { viewModel.recordCounterMetric() }
                    .buttonStyle(.borderedProminent)
            }
            HStack {
                Button("Incremental") { viewModel.recordIncrementalMetric() }
                    .buttonStyle(.borderedProminent)
                Button("UpDownCounter") { viewModel.recordUpDownCounterMetric() }
                    .buttonStyle(.borderedProminent)
            }

            Text("Track")
                .fontWeight(.bold)

            HStack {
                Button("Track (LDClient)") { viewModel.trackViaLDClient() }
                    .buttonStyle(.borderedProminent)
                Button("Track (LDObserve)") { viewModel.trackViaLDObserve() }
                    .buttonStyle(.borderedProminent)
            }
            HStack {
                Button("Track Screen View") { viewModel.trackScreenView() }
                    .buttonStyle(.borderedProminent)
            }

            Text("Error")
                .fontWeight(.bold)

            Button {
                viewModel.recordError()
            } label: {
                Text("Error")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Text("Logs")
                .fontWeight(.bold)

            HStack {
                Button {
                    viewModel.recordLogs()
                } label: {
                    Text("Log")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.recordLogWithContext()
                } label: {
                    Text("Log with Context")
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Traces")
                .fontWeight(.bold)

            HStack {
                Button {
                    viewModel.recordSpanAndVariation()
                } label: {
                    Text("Span & Flag Eval")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.triggerNestedSpans()
                } label: {
                    Text("Nested Spans")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

}

/// The set of sheets presentable from the main menu. Backing `MainMenuView.activeSheet` with a
/// single route keeps presentation (and "return to Main Menu" tracking) to one source of truth.
private enum MenuSheet: Identifiable {
    case maskingOneFieldUIKit
    case maskPropagationSwiftUI
    case maskPropagationUIKit
    case numberPad
    case storyboard
    #if os(iOS)
    case creditCardUIKit
    case creditCardSwiftUI
    case notebook
    case dialogsUIKit
    case dialogsSwiftUI
    #endif
    #if canImport(WebKit)
    case webView
    #endif

    var id: Self { self }
}

enum Colors {
    static let identifyTextColor = Color(
        red: 138/255,
        green: 158/255,
        blue: 255/255
    )
    
    static let identifyBgColor = Color(
        red: 18/255,
        green: 29/255,
        blue: 97/255
    )
}

private struct MaskingGridRow: View {
    let title: String
    let uikitAction: (() -> Void)?
    let swiftUIAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading).ldMask()
            Button("UIKit") { uikitAction?() }
                .disabled(uikitAction == nil)
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            Button("SwiftUI") { swiftUIAction?() }
                .disabled(swiftUIAction == nil)
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    MainMenuView()
}
