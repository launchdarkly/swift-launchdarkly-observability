import Foundation
import UIKit

public struct TouchSample: Sendable {
    public enum Phase : Sendable {
        case began
        case moved
        case ended
        case cancelled
    }
    
    public let phase: Phase
    public let id: ObjectIdentifier
    public let location: CGPoint
    public let timestamp: TimeInterval
    public let target: TouchTarget?

    
    public init(touch: UITouch, window: UIWindow, target: TouchTarget?) {
        self.id = ObjectIdentifier(touch)
        self.location = touch.location(in: window)
        self.timestamp = touch.timestamp
        self.target = target
        self.phase = switch touch.phase {
        case .began: .began
        case .moved: .moved
        case .ended: .ended
        case .cancelled: .cancelled
        default : .moved
        }
    }
}

typealias UIInteractionYield = @Sendable (UIInteraction) -> Void

final class TouchCaptureCoordinator {
    private let source: UIEventSource
    private let targetResolver: TargetResolving
    private let touchIntepreter: TouchIntepreter
    private let yield: UIInteractionYield
    private let receiverChecker: UIEventReceiverChecker

    init(targetResolver: TargetResolving = TargetResolver(),
         receiverChecker: UIEventReceiverChecker = UIEventReceiverChecker(),
         yield: @escaping UIInteractionYield) {
        self.targetResolver = targetResolver
        self.touchIntepreter = TouchIntepreter()
        self.source = UIWindowSwizzleSource()
        self.receiverChecker = receiverChecker
        self.yield = yield
    }
    
    func start() {
        let touchSampleStream = AsyncStream<TouchSample> { continuation in
            source.start { [weak self] event, window in
                // Main thread part of work
                guard let self else { return }
                guard let touches = event.allTouches else { return }
                guard receiverChecker.shouldTrack(window) else { return }
                
                for touch in touches {
                    let target: TouchTarget?
                    if touch.phase == .began || touch.phase == .ended {
                        target = targetResolver.resolve(view: touch.view, window: window, event: event)
                    } else {
                        target = nil
                    }
                    
                    let touchSample = TouchSample(touch: touch, window: window, target: target)
                    continuation.yield(touchSample)
                }
            }
        }
        
        Task.detached { [weak self] in
            guard let self else { return }
            // Bg thread part of work
            for await touchSample in touchSampleStream {
                touchIntepreter.process(touchSample: touchSample, yield: yield)
            }
        }
    }
}
