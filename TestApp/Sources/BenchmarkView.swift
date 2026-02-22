import SwiftUI
import LaunchDarklySessionReplay

struct BenchmarkView: View {
    private static let framesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Benchmark/mastodon")
    private let executor = BenchmarkExecutor()

    @State private var results = [BenchmarkResultRow]()
    @State private var isRunning = false
    @State private var showResults = false

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
        }
        .navigationTitle("Benchmark")
        .sheet(isPresented: $showResults) {
            BenchmarkResultsSheet(results: results)
        }
    }

    private func runBenchmark() {
        isRunning = true
        Task {
            let compressionResults = await executor.compression(framesDirectory: Self.framesDirectory)
            let baseline = compressionResults.first?.bytes ?? 1
            results = compressionResults.map { result in
                let pct = Double(result.bytes) / Double(baseline) * 100
                return BenchmarkResultRow(
                    name: result.compression.displayName,
                    bytes: result.bytes,
                    percent: String(format: "%.0f%%", pct)
                )
            }
            isRunning = false
            showResults = true
        }
    }
}

private struct BenchmarkResultRow: Identifiable {
    let id = UUID()
    let name: String
    let bytes: Int
    let percent: String

    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
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
