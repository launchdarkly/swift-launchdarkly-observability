import SwiftUI
import LaunchDarklySessionReplay

struct BenchmarkView: View {
    private static let framesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Benchmark/mastodon")
    private let benchmarkRuns = 3
    private let executor = BenchmarkExecutor()

    @State private var results = [BenchmarkResultRow]()
    @State private var isRunning = false
    @State private var showResults = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Button {
                runBenchmark()
            } label: {
                if isRunning {
                    ProgressView()
                } else {
                    Text("Mastodon iOS 200 sec walk")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
        }
        .navigationTitle("Benchmark")
        .sheet(isPresented: $showResults) {
            BenchmarkResultsSheet(results: results)
        }
        .alert("Benchmark Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func runBenchmark() {
        isRunning = true
        Task {
            do {
                let compressionResults = try await executor.compression(framesDirectory: Self.framesDirectory, runs: benchmarkRuns)
                let baseline = compressionResults.first?.bytes ?? 1
                results = compressionResults.map { result in
                    let pct = Double(result.bytes) / Double(baseline) * 100
                    return BenchmarkResultRow(
                        name: result.compression.displayName,
                        bytes: result.bytes,
                        captureTime: result.captureTime,
                        totalTime: result.totalTime,
                        percent: String(format: "%.0f%%", pct)
                    )
                }
                showResults = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isRunning = false
        }
    }
}

private struct BenchmarkResultRow: Identifiable {
    let id = UUID()
    let name: String
    let bytes: Int
    let captureTime: TimeInterval
    let totalTime: TimeInterval
    let percent: String

    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    var formattedCaptureTime: String {
        String(format: "%.2fs", captureTime)
    }

    var formattedTotalTime: String {
        String(format: "%.2fs", totalTime)
    }
}

private struct BenchmarkResultsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let results: [BenchmarkResultRow]

    var body: some View {
        NavigationStack {
            List(results) { row in
                HStack {
                    Text(row.name)
                    Spacer()
                    Text(row.percent)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                    (Text(row.formattedCaptureTime) + Text(" / ") + Text(row.formattedTotalTime).bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .trailing)
                    Text(row.formattedBytes)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private extension SessionReplayOptions.CompressionMethod {
    var displayName: String {
        switch self {
        case .screenImage:
            return "Screen Image"
        case .overlayTiles(let layers, let backtracking):
            return "layers: \(layers) backtracking: \(backtracking)"
        }
    }
}

#Preview {
    NavigationStack {
        BenchmarkView()
    }
}
