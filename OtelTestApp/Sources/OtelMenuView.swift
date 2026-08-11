import SwiftUI

/// Every button here drives one call on `LDObserve`. There is nothing to exercise automatically,
/// which is the point: this app is the manual counterpart to `TestApp`, for the OTel-only product.
struct OtelMenuView: View {
    @StateObject private var viewModel = OtelMenuViewModel()

    var body: some View {
        NavigationStack {
            List {
                sessionSection
                logsSection
                tracesSection
                metricsSection
                analyticsSection
                identifySection
                activitySection
            }
            .navigationTitle("LaunchDarkly OTel")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var sessionSection: some View {
        Section("Session") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Session ID")
                Text(viewModel.sessionId ?? "not started")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text("Every signal below is stamped with this session. Background the app for more than 3 seconds to rotate it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var logsSection: some View {
        Section("Logs") {
            ButtonRow {
                Button("Log") { viewModel.recordLog() }
                Button("Warning") { viewModel.recordWarning() }
            }
            ButtonRow {
                Button("Log with Span Context") { viewModel.recordLogWithSpanContext() }
                Button("Error") { viewModel.recordError() }
            }
        }
    }

    private var tracesSection: some View {
        Section("Traces") {
            ButtonRow {
                Button("Span") { viewModel.recordSpan() }
                Button("Nested Spans") { viewModel.recordNestedSpans() }
            }
            ButtonRow {
                Button("Span & Flag Eval") { viewModel.recordSpanAndVariation() }
            }
        }
    }

    private var metricsSection: some View {
        Section("Metrics") {
            ButtonRow {
                Button("Gauge") { viewModel.recordMetric() }
                Button("Histogram") { viewModel.recordHistogram() }
                Button("Count") { viewModel.recordCount() }
            }
            ButtonRow {
                Button("Incremental") { viewModel.recordIncr() }
                Button("UpDownCounter") { viewModel.recordUpDownCounter() }
            }
        }
    }

    private var analyticsSection: some View {
        Section("Analytics") {
            ButtonRow {
                Button("Track (LDObserve)") { viewModel.trackViaLDObserve() }
                Button("Track (LDClient)") { viewModel.trackViaLDClient() }
            }
            ButtonRow {
                Button("Screen View") { viewModel.trackScreenView() }
                Button("Click") { viewModel.trackClick() }
            }
        }
    }

    private var identifySection: some View {
        Section("Identify") {
            ButtonRow {
                Button("User") { viewModel.identifyUser() }
                Button("Multi") { viewModel.identifyMulti() }
                Button("Anonymous") { viewModel.identifyAnonymous() }
            }
        }
    }

    private var activitySection: some View {
        Section {
            if viewModel.activity.isEmpty {
                Text("No calls yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.activity) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.text)
                        Text(entry.time.formatted(.dateTime.hour().minute().second()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            HStack {
                Text("Recorded")
                Spacer()
                Button("Clear") { viewModel.clearActivity() }
                    .disabled(viewModel.activity.isEmpty)
            }
        }
    }
}

/// Lays buttons out edge to edge so a row of them stays tappable inside a `List`.
private struct ButtonRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

#Preview {
    OtelMenuView()
}
