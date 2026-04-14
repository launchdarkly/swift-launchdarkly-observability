#if os(tvOS)

import SwiftUI
import LaunchDarklyObservability
import LaunchDarklySessionReplay
import LaunchDarkly

struct TVMainMenuView: View {
    @StateObject private var viewModel = MainMenuViewModel()
    @State private var isSessionReplayEnabled = true
    @State private var showFruta = false
    @State private var showMaskingSimple = false
    @State private var showNumberPad = false

    var body: some View {
        TabView {
            sessionReplayTab
                .tabItem { Label("Session Replay", systemImage: "rectangle.on.rectangle") }
            instrumentationTab
                .tabItem { Label("Instrumentation", systemImage: "waveform.path.ecg") }
            metricsTab
                .tabItem { Label("Metrics", systemImage: "chart.bar.fill") }
            customerAPITab
                .tabItem { Label("Customer API", systemImage: "terminal.fill") }
        }
        .fullScreenCover(isPresented: $showFruta) {
            TVFrutaAppView()
        }
        .fullScreenCover(isPresented: $showMaskingSimple) {
            TVDismissableWrapper {
                MaskingElementsSimpleUIKitView()
            }
        }
        .fullScreenCover(isPresented: $showNumberPad) {
            TVDismissableWrapper {
                NumberPadView()
            }
        }
    }

    // MARK: - Session Replay

    private var sessionReplayTab: some View {
        ScrollView {
            VStack(spacing: 48) {
                headerView

                HStack(spacing: 24) {
                    Toggle(isOn: $isSessionReplayEnabled) {
                        Label("Session Replay", systemImage: "record.circle")
                    }
                    .onChange(of: isSessionReplayEnabled) { enabled in
                        if enabled {
                            LDReplay.shared.start()
                        } else {
                            LDReplay.shared.stop()
                        }
                    }
                }
                .padding(.horizontal, 80)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 40)], spacing: 40) {
                    TVCardButton(title: "One TextField", subtitle: "UIKit masking test", systemImage: "textformat") {
                        showMaskingSimple = true
                    }
                    TVCardButton(title: "Number Pad", subtitle: "SwiftUI number grid", systemImage: "number.square") {
                        showNumberPad = true
                    }
                    TVCardButton(title: "Fruta Gallery", subtitle: "Ingredients & smoothies", systemImage: "leaf.fill") {
                        showFruta = true
                    }
                }
                .padding(.horizontal, 80)
            }
            .padding(.vertical, 60)
        }
    }

    // MARK: - Instrumentation

    private var instrumentationTab: some View {
        ScrollView {
            VStack(spacing: 48) {
                headerView

                VStack(alignment: .leading, spacing: 32) {
                    Text("Identify")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 24) {
                        TVActionButton(title: "User", tint: Colors.identifyBgColor) {
                            viewModel.identifyUser()
                        }
                        TVActionButton(title: "Multi", tint: Colors.identifyBgColor) {
                            viewModel.identifyMulti()
                        }
                        TVActionButton(title: "Anonymous", tint: Colors.identifyBgColor) {
                            viewModel.identifyAnonymous()
                        }
                    }
                }
                .padding(.horizontal, 80)

                VStack(alignment: .leading, spacing: 32) {
                    Text("Network & Crash")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 24) {
                        TVActionButton(title: viewModel.isNetworkInProgress ? "Requesting…" : "Network Request", tint: .blue) {
                            Task { await viewModel.performNetworkRequest() }
                        }
                        TVActionButton(title: "Crash", tint: .red) {
                            viewModel.crash()
                        }
                    }
                }
                .padding(.horizontal, 80)
            }
            .padding(.vertical, 60)
        }
    }

    // MARK: - Metrics

    private var metricsTab: some View {
        ScrollView {
            VStack(spacing: 48) {
                headerView

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 40)], spacing: 40) {
                    TVCardButton(title: "Gauge", subtitle: "Record metric", systemImage: "gauge.medium") {
                        viewModel.recordMetric()
                    }
                    TVCardButton(title: "Histogram", subtitle: "Record histogram", systemImage: "chart.bar.xaxis") {
                        viewModel.recordHistogramMetric()
                    }
                    TVCardButton(title: "Counter", subtitle: "Record count", systemImage: "number") {
                        viewModel.recordCounterMetric()
                    }
                    TVCardButton(title: "Incremental", subtitle: "Increment counter", systemImage: "plus.circle") {
                        viewModel.recordIncrementalMetric()
                    }
                    TVCardButton(title: "Up/Down", subtitle: "Up-down counter", systemImage: "arrow.up.arrow.down") {
                        viewModel.recordUpDownCounterMetric()
                    }
                }
                .padding(.horizontal, 80)
            }
            .padding(.vertical, 60)
        }
    }

    // MARK: - Customer API

    private var customerAPITab: some View {
        ScrollView {
            VStack(spacing: 48) {
                headerView

                VStack(alignment: .leading, spacing: 32) {
                    Text("Errors & Logs")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 24) {
                        TVActionButton(title: "Error", tint: .red) {
                            viewModel.recordError()
                        }
                        TVActionButton(title: "Log", tint: .blue) {
                            viewModel.recordLogs()
                        }
                        TVActionButton(title: "Log with Context", tint: .indigo) {
                            viewModel.recordLogWithContext()
                        }
                    }
                }
                .padding(.horizontal, 80)

                VStack(alignment: .leading, spacing: 32) {
                    Text("Spans")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 24) {
                        TVActionButton(title: "Span & Flag Eval", tint: .green) {
                            viewModel.recordSpanAndVariation()
                        }
                        TVActionButton(title: "Nested Spans", tint: .teal) {
                            viewModel.triggerNestedSpans()
                        }
                    }
                }
                .padding(.horizontal, 80)
            }
            .padding(.vertical, 60)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)
            Text("LaunchDarkly Observability")
                .font(.title)
                .fontWeight(.semibold)
            Text(Date().formatted(.dateTime.hour().minute().second()))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - tvOS Card Button

private struct TVCardButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
        }
        .buttonStyle(.card)
    }
}

// MARK: - tvOS Action Button

private struct TVActionButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
        }
        .tint(tint)
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Dismissable Wrapper

private struct TVDismissableWrapper<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    TVMainMenuView()
}

#endif
