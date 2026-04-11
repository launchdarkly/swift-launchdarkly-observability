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
    @State private var isMaskingUIKitOneFieldEnabled: Bool = false
    @State private var isMaskingUIKitCreditCardEnabled: Bool = false
    @State private var isMaskingSwiftUICreditCardEnabled: Bool = false
    @State private var isNumberPadEnabled: Bool = false
    @State private var isNotebookEnabled: Bool = false
    @State private var isStoryboardEnabled: Bool = false
    @State private var isWebviewEnabled: Bool = false
    @State private var isDialogsUIKitEnabled: Bool = false
    @State private var isDialogsSwiftUIEnabled: Bool = false
    @State private var isSessionReplayEnabled: Bool = true
    var body: some View {
        NavigationStack(path: $path) {
            HStack {
                Image("Logo")
                Text("LaunchDarkly Observability")
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
        .sheet(isPresented: $isMaskingUIKitOneFieldEnabled) {
            MaskingElementsSimpleUIKitView()
        }
#if os(iOS)
        .sheet(isPresented: $isMaskingUIKitCreditCardEnabled) {
            MaskingCreditCardUIKitView()
        }
        .sheet(isPresented: $isMaskingSwiftUICreditCardEnabled) {
            MaskingCreditCardSwiftUIView()
        }
        .sheet(isPresented: $isNotebookEnabled) {
            NotebookView()
        }
        .sheet(isPresented: $isDialogsUIKitEnabled) {
            DialogsUIKitView()
        }
        .sheet(isPresented: $isDialogsSwiftUIEnabled) {
            DialogsSwiftUIView()
        }
#endif
        .sheet(isPresented: $isNumberPadEnabled) {
            NumberPadView()
        }
        .sheet(isPresented: $isStoryboardEnabled) {
            StoryboardRootView()
        }
#if canImport(WebKit)
        .sheet(isPresented: $isWebviewEnabled) {
            WebViewControllertView()
        }
#endif
    }

    // MARK: - Session Replay

    private var sessionReplaySection: some View {
        Section {
            MaskingGridRow(title: "One TextField", uikitAction: {
                isMaskingUIKitOneFieldEnabled = true
            }, swiftUIAction: nil)
#if os(iOS)
            MaskingGridRow(title: "Credit Card", uikitAction: {
                isMaskingUIKitCreditCardEnabled = true
            }) {
                isMaskingSwiftUICreditCardEnabled = true
            }
            MaskingGridRow(title: "Number Pad", uikitAction: nil) {
                isNumberPadEnabled = true
            }
            MaskingGridRow(title: "Dialogs", uikitAction: {
                isDialogsUIKitEnabled = true
            }) {
                isDialogsSwiftUIEnabled = true
            }
#endif
#if os(iOS)
            MaskingGridRow(title: "Fruta", uikitAction: nil) {
                path.append("fruta")
            }
#endif
            HStack {
                Button("Drawing") {
                    isNotebookEnabled = true
                }
                .buttonStyle(.borderedProminent)
                Button("Storyboard") {
                    isStoryboardEnabled = true
                }
                .buttonStyle(.borderedProminent)
#if canImport(WebKit)
                Button("WebView") {
                    isWebviewEnabled = true
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

            Text("Customer API")
                .fontWeight(.bold)

            HStack {
                Button {
                    viewModel.recordError()
                } label: {
                    Text("Error")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

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
                .frame(maxWidth: .infinity, alignment: .leading)
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
