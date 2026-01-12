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
    @State private var identifyText: String = ""
    
    var body: some View {
        NavigationStack(path: $path) {
            HStack {
                Image("Logo")
                Text("LaunchDarkly Observability")
            }
            
            List {
                #if os(iOS)
                NavigationLink("Fruta (SwiftUI)", value: "fruta")
                #endif
                NavigationLink(destination: MaskingElementsView()) {
                    Text("Masking Elements (SwiftUI)")
                }

                FauxLinkToggleRow(title: "Masking One TextField (UIKit)", isOn: $isMaskingUIKitOneFieldEnabled)
#if os(iOS)
                FauxLinkToggleRow(title: "Masking Credit Card (UIKit)", isOn: $isMaskingUIKitCreditCardEnabled)
                FauxLinkToggleRow(title: "Masking Credit Card (SwiftUI)", isOn: $isMaskingSwiftUICreditCardEnabled)
                FauxLinkToggleRow(title: "Number Pad (SwiftUI)", isOn: $isNumberPadEnabled)
#endif

                FauxLinkToggleRow(title: "Notebook (SwiftUI)", isOn: $isNotebookEnabled)
                FauxLinkToggleRow(title: "Storyboad (UIKit)", isOn: $isStoryboardEnabled)
#if canImport(WebKit)
                FauxLinkToggleRow(title: "WebView (WebKit)", isOn: $isWebviewEnabled)
#endif
#if os(iOS)
                NavigationLink(destination: SystemUnderPressureView()) {
                    Text("Simulate System Under Pressure")
                }
#endif
                
                HStack {
                    Text("Identify:")
                    
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
                
                HStack {
                    Button {
                        viewModel.recordSpanAndVariation()
                    } label: {
                        Text("span")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        viewModel.recordLogs()
                    } label: {
                        Text("logs")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        viewModel.recordCounterMetric()
                    } label: {
                        Text("metric: counter")
                    }
                    .buttonStyle(.borderedProminent)
                }
                
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
                        Text("network request: span")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isNetworkInProgress)
               
                HStack {
                    Button {
                        viewModel.recordError()
                    } label: {
                        Text("error")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    Button {
                        viewModel.crash()
                    } label: {
                        Text("Crash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                
   
            }.background(Color.clear)
            .navigationDestination(for: String.self) { value in
                if value == "fruta" {
                    FrutaAppView()
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

#if os(iOS)
        .sheet(isPresented: $isMaskingUIKitCreditCardEnabled) {
            MaskingCreditCardUIKitView()
        }.sheet(isPresented: $isMaskingSwiftUICreditCardEnabled) {
            MaskingCreditCardSwiftUIView()
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
        }
#if canImport(WebKit)
        .sheet(isPresented: $isWebviewEnabled) {
            WebViewControllertView()
        }
#endif
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
    MainMenuView()
}
