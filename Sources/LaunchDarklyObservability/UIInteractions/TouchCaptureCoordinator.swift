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

public typealias TouchInteractionYield = @Sendable (TouchInteraction) -> Void

final class TouchCaptureCoordinator {
    private let source: UIEventSource
    private let targetResolver: TargetResolving
    private let touchIntepreter: TouchIntepreter
    private let receiverChecker: UIEventReceiverChecker
    var yield: TouchInteractionYield?
    
    init(targetResolver: TargetResolving = TargetResolver(),
         receiverChecker: UIEventReceiverChecker = UIEventReceiverChecker()) {
        self.targetResolver = targetResolver
        self.touchIntepreter = TouchIntepreter()
        self.source = UIWindowSwizzleSource()
        self.receiverChecker = receiverChecker
    }
    
    func start() {
        let touchSampleStream = AsyncStream<TouchSample> { continuation in
            source.start { [weak self] event, window in
                // Main thread part of work
                guard let self else { return }
                
                guard receiverChecker.shouldTrack(window) else { return }
                
                switch event.type {
                case .touches:
                    processTouches(event: event, window: window, continuation: continuation)
                case .presses:
                    processPresses(event: event, window: window, continuation: continuation)
                default:
                    break
                }
            }
        }
        
        Task.detached(priority: .background) { [weak self] in
            guard let self, let yield else { return }
            // Bg thread part of work
            for await touchSample in touchSampleStream {
                touchIntepreter.process(touchSample: touchSample, yield: yield)
            }
        }
    }
    
    private func processTouches(
        event: UIEvent,
        window: UIWindow,
        continuation: AsyncStream<TouchSample>.Continuation
    ) {
        guard let touches = event.allTouches else { return }
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
    
    private func processPresses(
        event _: UIEvent,
        window _: UIWindow,
        continuation _: AsyncStream<TouchSample>.Continuation
    ) {
        
    }
}
