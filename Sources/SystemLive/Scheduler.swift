import Foundation
import OSLog

import Common

final class Scheduler {
    private let queue = DispatchQueue(label: "com.launchdarkly.system.scheduler")
    private var workItems: [UUID: DispatchWorkItem] = [:]
    private var timers: [UUID: DispatchSourceTimer] = [:]
    
    private var timer: DispatchSourceTimer?
    private let logger: ObservabilityLogger = .init()
    
    @discardableResult func schedule(
        after delay: TimeInterval,
        task: @escaping () -> Void,
        completion: (() -> Void)? = nil
    ) -> UUID {
        let id = UUID()
        let log = logger.log
        let workItem = DispatchWorkItem {
            os_log("%{public}@", log: log, type: .info, "scheduled task \(id.uuidString)started after \(delay)s")
            task()
            os_log("%{public}@", log: log, type: .info, "scheduled task \(id.uuidString) completed")
            completion?()
        }
        workItems[id] = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
        
        return id
    }
    
    func cancelScheduledTask(id: UUID) {
        workItems[id]?.cancel()
        timers.removeValue(forKey: id)
        os_log("%{public}@", log: logger.log, type: .info, "Task \(id.uuidString) cancelled")
    }
    
    @discardableResult func scheduleRepeating(
        every interval: TimeInterval,
        task: @escaping () -> Void,
        completion: (() -> Void)? = nil
    ) -> UUID {
        let id = UUID()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        let log = logger.log
        timer.setEventHandler {
            os_log("%{public}@", log: log, type: .info, "Repeating task \(id.uuidString) started (interval: \(interval)s)")
            task()
            os_log("%{public}@", log: log, type: .info, "Repeating task \(id.uuidString) completed")
            completion?()
        }
        timer.resume()
        timers[id] = timer
        
        return id
    }
    
    func stopRepeating(id: UUID) {
        timers[id]?.cancel()
        timers.removeValue(forKey: id)
        os_log("%{public}@", log: logger.log, type: .info, "Repeating task \(id.uuidString) stopped")
    }
}
