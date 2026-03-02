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
    @State private var signatureResult: String?

    var body: some View {
        VStack(spacing: 20) {
            Button {
                runBenchmark()
            } label: {
                if isRunning {
                    ProgressView()
                } else {
                    Text("Mastodon Compression")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)

            Button {
                runSignatureBenchmark()
            } label: {
                Text("Compute ImageSignature")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)

            if let signatureResult {
                Text(signatureResult)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Benchmark")
        .sheet(isPresented: $showResults) {
            BenchmarkResultsSheet(results: results)
        }
    }

    private func runBenchmark() {
        isRunning = true
        Task {
            let compressionResults = await executor.compression(framesDirectory: Self.framesDirectory, runs: benchmarkRuns)
            let baseline = compressionResults.first?.bytes ?? 1
            results = compressionResults.map { result in
                let pct = Double(result.bytes) / Double(baseline) * 100
                return BenchmarkResultRow(
                    name: result.compression.displayName,
                    bytes: result.bytes,
                    executionTime: result.executionTime,
                    percent: String(format: "%.0f%%", pct)
                )
            }
            isRunning = false
            showResults = true
        }
    }

    private func runSignatureBenchmark() {
        isRunning = true
        signatureResult = nil
        Task.detached(priority: .userInitiated) {
            do {
                let r = try executor.signatureBenchmark(framesDirectory: Self.framesDirectory)
                let mbString = String(format: "%.1f MB", Double(r.totalBytes) / (1024 * 1024))
                let timeString = String(format: "%.3fs", r.elapsedTime)
                let result = "\(timeString) — \(mbString) (\(r.frameCount) frames)"
                await MainActor.run {
                    signatureResult = result
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    signatureResult = "Error: \(error.localizedDescription)"
                    isRunning = false
                }
            }
        }
    }
}

private struct BenchmarkResultRow: Identifiable {
    let id = UUID()
    let name: String
    let bytes: Int
    let executionTime: TimeInterval
    let percent: String

    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    var formattedExecutionTime: String {
        String(format: "%.2fs", executionTime)
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
                    Text(row.formattedExecutionTime)
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .trailing)
                    Text(row.formattedBytes)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.subheadline)
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
