import UIKit

fileprivate final class MemoryPressureMonitor {
    var onLevelDidChange: ((DispatchSource.MemoryPressureEvent) -> Void)?
    var level: DispatchSource.MemoryPressureEvent = .normal
    private var dispatchSource: DispatchSourceMemoryPressure
    
    init() {
        self.level = .normal
        self.dispatchSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.critical, .warning, .normal],
            queue: .main
        )
        self.dispatchSource.setEventHandler { [weak self] in
            guard let event = self?.dispatchSource.data else { return }
            self?.level = event
            self?.onLevelDidChange?(event)
        }
        self.dispatchSource.activate()
    }
    
    func start() {
        dispatchSource.resume()
    }
    
    func stop() {
        dispatchSource.suspend()
    }
}

extension DispatchSource.MemoryPressureEvent {
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

final class MemoryPressurizer: ObservableObject {
    @Published var memoryPressureLevel: DispatchSource.MemoryPressureEvent = .normal
    enum MemoryPressureLoadSize: CaseIterable {
        case small
        case medium
        case large
        case extraLarge
        
        var megabytes: Int {
            switch self {
            case .small:
                return 300
            case .medium:
                return 500
            case .large:
                return 800
            case .extraLarge:
                return 1300
            }
        }
        
        var name: String {
            switch self {
            case .small:
                return "small"
            case .large:
                return "large"
            case .medium:
                return "medium"
            case .extraLarge:
                return "extra large"
            }
        }
    }
    private let memoryPressureMonitor: MemoryPressureMonitor
    private var buffers: [Data]
    
    init() {
        self.memoryPressureMonitor = MemoryPressureMonitor()
        self.buffers = []
        self.memoryPressureMonitor.onLevelDidChange = { [weak self] level in
            self?.memoryPressureLevel = level
            self?.objectWillChange.send()
        }
    }
    
    func pressurize(by loadSize: MemoryPressureLoadSize = .medium) {
        pressure(by: loadSize)
    }
    
    func release() {
        releaseBuffers()
    }
    
    private func releaseBuffers() {
        buffers.removeAll()
    }
    
    private func pressure(by size: MemoryPressureLoadSize) {
        // Allocate data blocks
        let blockSize = 10 * 1024 * 1024 // 10 MB
        let count = size.megabytes / 10
        for _ in 0..<count {
            var randomBytes = [UInt8](repeating: 0, count: blockSize)
            _ = SecRandomCopyBytes(kSecRandomDefault, blockSize, &randomBytes)
            let randomData = Data(randomBytes)
            buffers.append(randomData)
        }
    }
}
