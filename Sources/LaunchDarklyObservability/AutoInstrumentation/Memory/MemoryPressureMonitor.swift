import Foundation
import OpenTelemetrySdk

final class MemoryPressureMonitor: AutoInstrumentation {
    private let options: Options
    private let appLogBuilder: AppLogBuilder
    private let yield: (ReadableLogRecord) async -> Void
    private var source: DispatchSourceMemoryPressure?
    
    init(options: Options, appLogBuilder: AppLogBuilder, yield: @escaping (ReadableLogRecord) async -> Void) {
        self.options = options
        self.appLogBuilder = appLogBuilder
        self.yield = yield
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
        let localYield = yield
        source?.setEventHandler { [weak self] in
            Task {
                guard let self, let event = self.source?.data else { return }
                /// Report only if memory pressure is warning or critical
                guard [DispatchSource.MemoryPressureEvent.warning, .critical].contains(event) else {
                    return
                }
                
                guard let log = self.appLogBuilder.buildLog(message: "applicationDidReceiveMemoryWarning",
                                                            severity: .warn,
                                                            attributes: [SemanticConvention.systemMemoryWarning: .string(event.name)]) else {
                    return
                }
                
                await localYield(log)
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
