import SwiftUI

struct SystemUnderPressureView: View {
    @ObservedObject var memoryPressureMonitor = MemoryPressureMonitor()
    var body: some View {
        VStack(spacing: 34.0) {
            Label {
                Text(
                    { () -> String in
                        switch memoryPressureMonitor.level {
                        case .all:
                         return "All"
                        case .critical:
                            return "Critical"
                        case .warning:
                            return "Warning"
                        case .normal:
                            return "Normal"
                        default:
                            return "Normal"
                        }
                    }()
                )
            } icon: {
                Image(systemName: "memorychip")
            }

            Button {
                simulateMemoryWarning(level: .low)
            } label: {
                Text("Low Memory Pressure")
            }
            Button {
                simulateMemoryWarning(level: .veryLow)
            } label: {
                Text("Very Low Memory Pressure")
            }
            Button {
                simulateMemoryWarning(level: .criticalLow)
            } label: {
                Text("Critical Low Memory Pressure")
            }
        }
        .onAppear {
            memoryPressureMonitor.start()
        }
        .onDisappear {
            memoryPressureMonitor.stop()
        }
    }
}

final class MemoryPressureMonitor: ObservableObject {
    @Published var level: DispatchSource.MemoryPressureEvent = .normal
    private var dispatchSource: DispatchSourceMemoryPressure?
    @State private var isMonitoring = false
    
    func start() {
        guard !isMonitoring else { return }
        isMonitoring.toggle()
        dispatchSource = DispatchSource.makeMemoryPressureSource(
            eventMask: .all,
            queue: .main
        )
        dispatchSource?.setEventHandler { [weak self] in
            let event = self?.dispatchSource?.data
            self?.level = event ?? .normal
            if event?.contains(.warning) == true {
                print("Memory pressure warning detected!")
                // Respond to memory warning
            }
            if event?.contains(.critical) == true {
                print("Critical memory pressure detected!")
                // Respond to critical memory pressure
            }
        }
        dispatchSource?.resume()
    }
    
    func stop() {
        isMonitoring = false
        dispatchSource?.cancel()
        dispatchSource = nil
    }
}
