import SwiftUI
import LaunchDarklyObservability
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

struct ContentView: View {
    @State private var isMaskingUIKitOneFieldEnabled: Bool = false
    @State private var isMaskingUIKitCreditCardEnabled: Bool = false
    @State private var isNumberPadEnabled: Bool = false
    @State private var isNotebookEnabled: Bool = false
    @State private var isStoryboardEnabled: Bool = false
    @State private var isWebviewEnabled: Bool = false

    @State private var buttonPressed: Bool = false
    @State private var errorPressed: Bool = false
    @State private var counterMetricPressed: Bool = false
    @State private var logsPressed: Bool = false
    @State private var crashPressed: Bool = false
    @State private var networkPressed: Bool = false
    
    var body: some View {
        NavigationStack {
            HStack {
                Image("Logo")
                Text("LaunchDarkly Observability")
            }
            
            List {
                #if os(iOS)
                NavigationLink(destination: FrutaAppView()) {
                    Text("Fruta (SwiftUI)")
                }
                #endif
                NavigationLink(destination: MaskingElementsView()) {
                    Text("Masking Elements (SwiftUI)")
                }

                FauxLinkToggleRow(title: "Masking One TextField (UIKit)", isOn: $isMaskingUIKitOneFieldEnabled)
#if os(iOS)
                FauxLinkToggleRow(title: "Masking Credit Card (UIKit)", isOn: $isMaskingUIKitCreditCardEnabled)
                FauxLinkToggleRow(title: "Number Pad (SwiftUI)", isOn: $isNumberPadEnabled)
#endif

                FauxLinkToggleRow(title: "Notebook (SwiftUI)", isOn: $isNotebookEnabled)
                FauxLinkToggleRow(title: "Storyboad (UIKit)", isOn: $isStoryboardEnabled)
                FauxLinkToggleRow(title: "WebView (WebKit)", isOn: $isWebviewEnabled)
                
                NavigationLink(destination: SystemUnderPressureView()) {
                    Text("Simulate System Under Pressure")
                }
                
                HStack {
                    Button {
                        buttonPressed.toggle()
                    } label: {
                        Text("span")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        logsPressed.toggle()
                    } label: {
                        Text("logs")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        counterMetricPressed.toggle()
                    } label: {
                        Text("metric: counter")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button {
                    networkPressed.toggle()
                } label: {
                    if networkPressed {
                        ProgressView {
                            Text("get request to launchdarkly.com...")
                        }
                    } else {
                        Text("network request: span")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(networkPressed)
               
                HStack {
                    Button {
                        errorPressed.toggle()
                    } label: {
                        Text("error")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    Button {
                        crashPressed.toggle()
                    } label: {
                        Text("Crash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                


            }.background(Color.clear)
        }
        .task(id: errorPressed) {
            guard errorPressed else { return }
            LDObserve.shared.recordError(
                error: Failure.crash,
                attributes: [:])
            errorPressed.toggle()
        }
        .task(id: buttonPressed) {
            guard buttonPressed else { return }
            let aSpan = LDObserve.shared.startSpan(
                name: "button-pressed",
                attributes: [:]
            )
            LDClient.get()?.boolVariation(
                forKey: "my-feature",
                defaultValue: false
            )
            
            aSpan.end()
            buttonPressed.toggle()
        }
        .task(id: counterMetricPressed) {
            guard counterMetricPressed else { return }
            LDObserve.shared.recordCount(
                metric: .init(
                    name: "press-count",
                    value: 1,
                    timestamp: .now
                )
            )
            counterMetricPressed.toggle()
        }
        .task(id: logsPressed) {
            guard logsPressed else { return }
            LDObserve.shared.recordLog(
                message: "logs-button-pressed",
                severity: .info
                , attributes: ["testuser": .string("andrey")])
            logsPressed.toggle()
        }
        .task(id: crashPressed) {
            guard crashPressed else { return }
            
            fatalError()
            
            crashPressed.toggle()
        }
        .task(id: networkPressed) {
            guard networkPressed else { return }
            
            let url = URL(string: "https://launchdarkly.com/")!
            do {
                let (data, urlResponse) = try await URLSession.shared.data(from: url)
                networkPressed.toggle()
            } catch {
                networkPressed.toggle()
            }
        }
#if os(iOS)
        .sheet(isPresented: $isMaskingUIKitCreditCardEnabled) {
            MaskingCreditCardUIKitView()
        }.sheet(isPresented: $isNotebookEnabled) {
            NotebookView()
        }
        #endif
        .sheet(isPresented: $isMaskingUIKitOneFieldEnabled) {
            MaskingElementsSimpleUIKitView()
        }.sheet(isPresented: $isNumberPadEnabled) {
            NumberPadView()
        }.sheet(isPresented: $isStoryboardEnabled) {
            StoryboardRootView()
        }.sheet(isPresented: $isWebviewEnabled) {
            WebViewControllertView()
        }
    }
}


struct FauxLinkToggleRow: View {
    private struct NoDestinationTag: Hashable {}
    
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        ZStack {
            // Visuals only: system chevron/spacing
            NavigationLink(value: NoDestinationTag()) {
                Text(title)
            }
            .allowsHitTesting(false) // <- disables all taps on the link (incl. chevron)
            
            // Full-row tap handler
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle()) // full-row hit area
                .onTapGesture {
                    isOn.toggle()
                }
        }
    }
}


#Preview {
    ContentView()
}
