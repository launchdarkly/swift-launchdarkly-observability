import SwiftUI

struct CountdownTimerView: View {
    let duration: Int
    let onComplete: () -> Void

    @State private var remaining: Int
    @State private var completed = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(duration: Int = 60, onComplete: @escaping () -> Void) {
        self.duration = duration
        self.onComplete = onComplete
        _remaining = State(initialValue: duration)
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: CGFloat(remaining) / CGFloat(duration))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)

                VStack(spacing: 4) {
                    Text(timeString)
                        .font(.system(size: 40, weight: .medium, design: .monospaced))
                    Text("Time Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Stop") {
                completed = true
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .onReceive(timer) { _ in
            guard !completed else { return }
            if remaining > 0 {
                remaining -= 1
            } else {
                completed = true
                onComplete()
            }
        }
    }

    private var timeString: String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
