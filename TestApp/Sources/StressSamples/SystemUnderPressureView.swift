import SwiftUI

struct SystemUnderPressureView: View {
    @StateObject private var monitor = MemoryPressureMonitorV2()
    private let memoryPressureSimulator = MemoryPressureSimulator()
    var body: some View {
        VStack(spacing: 34.0) {
            Label {
                Text(monitor.memoryPressureStatus)
                    .font(.headline)
                    .padding()
            } icon: {
                Image(systemName: "memorychip")
            }

            Button {
                memoryPressureSimulator.simulatePressure(level: .low)
            } label: {
                Text("Low Memory Pressure")
            }
            Button {
                memoryPressureSimulator.simulatePressure(level: .veryLow)
            } label: {
                Text("Very Low Memory Pressure")
            }
            Button {
                memoryPressureSimulator.simulatePressure(level: .criticalLow)
            } label: {
                Text("Critical Low Memory Pressure")
            }
        }
        .onAppear {
            monitor.activate()
        }
        .onDisappear {
            monitor.deactivate()
            memoryPressureSimulator.releaseBuffers()
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
            eventMask: [.critical, .warning, .normal],
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
        dispatchSource?.activate()
    }
    
    func stop() {
        isMonitoring = false
        dispatchSource?.cancel()
        dispatchSource = nil
    }
}

class MemoryPressureMonitorV2: ObservableObject {
        @Published var memoryPressureStatus: String = "Normal"
        private var memoryPressureSource: DispatchSourceMemoryPressure?

        init() {
            memoryPressureSource = DispatchSource.makeMemoryPressureSource(
                eventMask: [.critical, .warning, .normal],
                queue: .main // Use the main queue for UI updates
            )

            memoryPressureSource?.setEventHandler { [weak self] in
                guard let self = self else { return }
                let event = self.memoryPressureSource?.data
                if event?.contains(.critical) == true {
                    self.memoryPressureStatus = "Critical Memory Pressure!"
                    // Perform critical memory cleanup actions here
                } else if event?.contains(.warning) == true {
                    self.memoryPressureStatus = "Memory Warning!"
                    // Perform less aggressive memory cleanup actions here
                } else if event?.contains(.normal) == true {
                    self.memoryPressureStatus = "Normal Memory Pressure"
                }
            }

            memoryPressureSource?.setCancelHandler {
                print("Memory pressure source cancelled.")
            }
        }

        func activate() {
            memoryPressureSource?.activate()
        }

        func deactivate() {
            memoryPressureSource?.cancel()
        }

        deinit {
            deactivate()
        }
    }
