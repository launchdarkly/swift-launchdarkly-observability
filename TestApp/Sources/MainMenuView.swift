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
    @State private var isSessionReplayEnabled: Bool = true
    
    var body: some View {
        NavigationStack(path: $path) {
            HStack {
                Image("Logo")
                Text("LaunchDarkly Observability")
            }
            
            List {
                maskingSection
                observabilitySection
                benchmarkSection
            }
            .background(Color.clear)
            .navigationDestination(for: String.self) { value in
                switch value {
                case "fruta":
                    FrutaAppView()
                default:
                    EmptyView()
                }
            }
        }
        .onChange(of: path) { newValue in
            if !newValue.contains("fruta") {
                if AppTabNavigation.pullPushLoop > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.9...1.1)) {
                        path.append("fruta")
                    }
                }
            }
        }
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

    // MARK: - Masking

    private var maskingSection: some View {
        Section("Masking") {
            Toggle("Session Replay", isOn: $isSessionReplayEnabled)
                .fontWeight(.bold)
                .onChange(of: isSessionReplayEnabled) { enabled in
                    if enabled {
                        LDReplay.shared.start()
                    } else {
                        LDReplay.shared.stop()
                    }
                }

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
#endif
            MaskingGridRow(title: "Notebook", uikitAction: nil) {
                isNotebookEnabled = true
            }
#if os(iOS)
            MaskingGridRow(title: "Fruta", uikitAction: nil) {
                path.append("fruta")
            }
#endif
            MaskingGridRow(title: "Storyboard", uikitAction: {
                isStoryboardEnabled = true
            }, swiftUIAction: nil)
#if canImport(WebKit)
            MaskingGridRow(title: "WebView", uikitAction: {
                isWebviewEnabled = true
            }, swiftUIAction: nil)
#endif
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

            Button {
                viewModel.recordCounterMetric()
            } label: {
                Text("Counter")
            }
            .buttonStyle(.borderedProminent)

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
                    Text("Logs")
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                viewModel.recordSpanAndVariation()
            } label: {
                Text("Span & Flag Eval")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Benchmark

    private var benchmarkSection: some View {
        Section("Benchmark") {
            NavigationLink(destination: BenchmarkView()) {
                Text("Benchmark")
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
