import Foundation

final class MemoryPressureMonitor: AutoInstrumentation {
    private let options: Options
    private let logsApi: LogsApi
    private var source: DispatchSourceMemoryPressure?
    
    init(options: Options, logsApi: LogsApi) {
        self.options = options
        self.logsApi = logsApi
    }
    
    func start() {
        startMonitoring()
    }
    
    func stop() {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.critical, .warning],
            queue: .global(qos: .background)
        )
        source?.setEventHandler { [weak self] in
            Task {
                guard let self, let event = self.source?.data else { return }
                /// Report only if memory pressure is warning or critical
                guard [DispatchSource.MemoryPressureEvent.warning, .critical].contains(event) else {
                    return
                }
                self.logsApi.recordLog(
                    message: "applicationDidReceiveMemoryWarning",
                    severity: .warn,
                    attributes: [
                        SemanticConvention.systemMemoryWarning: .string(event.name)
                    ]
                )
            }
        }
        source?.activate()
    }
    
    private func stopMonitoring() {
        source?.cancel()
        source = nil
    }
}

private extension DispatchSource.MemoryPressureEvent {
    var name: String {
        switch self {
        case .all: return "all"
        case .critical: return "critical"
        case .normal: return "normal"
        case .warning: return "warning"
        default: return "unknown"
        }
    }
}
