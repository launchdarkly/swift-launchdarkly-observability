import Foundation
import UIKit

enum InteractionCaptureItem: Sendable {
    case touch(TouchSample)
    case press(PressInteraction)
}

struct TouchSample: Sendable {
    enum Phase : Sendable {
        case began
        case moved
        case ended
        case cancelled
        case unknown
    }
    
    let phase: Phase
    let id: ObjectIdentifier
    let location: CGPoint
    // relative to system startup time
    let timestamp: TimeInterval
    let target: TouchTarget?

    
    init(touch: UITouch, window: UIWindow, target: TouchTarget?) {
        self.id = ObjectIdentifier(touch)
        self.location = touch.location(in: window)
        self.timestamp = touch.timestamp
        self.target = target
        self.phase = switch touch.phase {
        case .began: .began
        case .moved: .moved
        case .ended: .ended
        case .cancelled: .cancelled
        @unknown
        default : .unknown
        }
    }
}

public typealias TouchInteractionYield = @Sendable (TouchInteraction) -> Void
public typealias PressInteractionYield = @Sendable (PressInteraction) -> Void

final class InputCaptureCoordinator {
    private let source: UIEventSource
    private let targetResolver: TargetResolving
    private let touchInterpreter: TouchInterpreter
    private let receiverChecker: UIEventReceiverChecker
    var onTouch: TouchInteractionYield?
    var onPress: PressInteractionYield?
    
    init(targetResolver: TargetResolving = TargetResolver(),
         receiverChecker: UIEventReceiverChecker = UIEventReceiverChecker()) {
        self.targetResolver = targetResolver
        self.touchInterpreter = TouchInterpreter()
        self.source = UIWindowSwizzleSource()
        self.receiverChecker = receiverChecker
    }
    
    func start() {
        let captureStream = AsyncStream<InteractionCaptureItem> { continuation in
            source.start { [weak self] event, window in
                // Main thread part of work
                guard let self else { return }
                
                let trackWindow = receiverChecker.shouldTrack(window)
                
                switch event.type {
                case .touches:
                    if trackWindow {
                        processTouches(event: event, window: window, continuation: continuation)
                    } else {
                        processTouchesAsPress(event: event, window: window, continuation: continuation)
                    }
                case .presses:
                    processPresses(event: event, window: window, continuation: continuation)
                default:
                    // `UIPhysicalKeyboardEvent` and other `UIPressesEvent` subclasses can use a `type`
                    // not exposed on `UIEvent.EventType` yet, so they fall through here instead of `.presses`.
                    if event is UIPressesEvent {
                        processPresses(event: event, window: window, continuation: continuation)
                    }
                }
            }
        }
        
        Task.detached(priority: .background) { [weak self] in
            guard let self, let onTouch else { return }
            // Bg thread part of work
            for await item in captureStream {
                switch item {
                case .touch(let touchSample):
                    touchInterpreter.process(touchSample: touchSample, yield: onTouch)
                case .press(let sample):
                    onPress?(sample)
                }
            }
        }
    }
    
    private func processTouchesAsPress(
        event: UIEvent,
        window: UIWindow,
        continuation: AsyncStream<InteractionCaptureItem>.Continuation
    ) {
        guard let touches = event.allTouches else { return }
        for touch in touches {
            guard touch.phase == .began || touch.phase == .ended else { continue }
            let target = targetResolver.resolve(view: touch.view, window: window, event: event)
            let interaction = PressInteraction(
                phase: PressInteraction.phase(forTouch: touch.phase),
                timestamp: touch.timestamp,
                target: target,
                isKeyboardOriginated: true
            )
            if case let .other = interaction.kind { continue }
            
            continuation.yield(.press(interaction))
        }
    }
    
    private func processTouches(
        event: UIEvent,
        window: UIWindow,
        continuation: AsyncStream<InteractionCaptureItem>.Continuation
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
            continuation.yield(.touch(touchSample))
        }
    }
    
    private func processPresses(
        event: UIEvent,
        window: UIWindow,
        continuation: AsyncStream<InteractionCaptureItem>.Continuation
    ) {
        guard let pressesEvent = event as? UIPressesEvent else { return }
        for press in pressesEvent.allPresses {
            guard press.phase == .began || press.phase == .ended else { continue }
            let target = targetResolver.resolve(press: press, window: window)
            let interaction = PressInteraction(press: press, target: target)
            if case let .other = interaction.kind { continue }
            
            continuation.yield(.press(interaction))
        }
    }
}
