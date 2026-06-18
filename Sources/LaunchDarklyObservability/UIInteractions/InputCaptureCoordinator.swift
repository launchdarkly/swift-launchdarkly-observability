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
    /// Session id fixed at main-thread capture time (with location/target).
    let sessionId: String
    /// Active screen (`event.screen_id`/`event.screen_name`) read on the main thread at capture
    /// time. Fixed here - rather than later on the background interpreter/consumer - so a navigation
    /// or `screen_view` recorded after the finger lifts can't misattribute the tap to a later screen.
    let screenId: String?
    let screenName: String?

    init(touch: UITouch, window: UIWindow, target: TouchTarget?, sessionId: String, screenId: String?, screenName: String?) {
        self.id = ObjectIdentifier(touch)
        self.location = touch.location(in: window)
        self.timestamp = touch.timestamp
        self.target = target
        self.sessionId = sessionId
        self.screenId = screenId
        self.screenName = screenName
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
/// Resolves the active screen (`event.screen_id` / `event.screen_name`) at the instant of a tap.
/// Read on the main thread at capture time so it reflects the screen the tap actually landed on.
public typealias ScreenInfoProvider = @Sendable () -> (screenId: String?, screenName: String?)

final class InputCaptureCoordinator {
    private let source: UIEventSource
    private let targetResolver: TargetResolving
    private let touchInterpreter: TouchInterpreter
    private let pressInterpreter: PressInterpreter
    private let receiverChecker: UIEventReceiverChecker
    private let sessionIdProvider: @Sendable () -> String
    private let screenInfoProvider: ScreenInfoProvider
    var onTouch: TouchInteractionYield?
    var onPress: PressInteractionYield?

    init(targetResolver: TargetResolving = TargetResolver(),
         receiverChecker: UIEventReceiverChecker = UIEventReceiverChecker(),
         sessionIdProvider: @Sendable @escaping () -> String,
         screenInfoProvider: @escaping ScreenInfoProvider = { (nil, nil) }) {
        self.targetResolver = targetResolver
        self.touchInterpreter = TouchInterpreter()
        self.pressInterpreter = PressInterpreter()
        self.source = UIWindowSwizzleSource()
        self.receiverChecker = receiverChecker
        self.sessionIdProvider = sessionIdProvider
        self.screenInfoProvider = screenInfoProvider
    }
    
    func start() {
        let captureStream = AsyncStream<InteractionCaptureItem> { continuation in
            source.start { [weak self] event, window, dispatchOriginal in
                // Main thread part of work
                guard let self else { dispatchOriginal(); return }
                
                let trackWindow = receiverChecker.shouldTrack(window)
                
                switch event.type {
                case .touches:
                    if trackWindow {
                        // Sample the active screen BEFORE the app handles the event. A tap handler
                        // that navigates synchronously (e.g. list row -> detail) updates the screen
                        // stack during `dispatchOriginal()`; sampling first keeps the tap attributed
                        // to the screen it actually landed on rather than the destination. Target /
                        // `ldId` resolution still happens after dispatch (inside `processTouches`),
                        // because the SwiftUI `.ldClick` gesture only registers its id while the app
                        // processes the event.
                        let screen = screenInfoProvider()
                        dispatchOriginal()
                        processTouches(event: event, window: window, screen: screen, continuation: continuation)
                    } else {
                        dispatchOriginal()
                        processTouchesAsPress(event: event, window: window, continuation: continuation)
                    }
                case .presses:
                    dispatchOriginal()
                    processPresses(event: event, window: window, continuation: continuation)
                default:
                    dispatchOriginal()
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
                    if let onPress {
                        pressInterpreter.process(pressInteraction: sample, yield: onPress)
                    }
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
        let sessionId = sessionIdProvider()
        for touch in touches {
            guard touch.phase == .began else { continue }
            let target = targetResolver.resolve(view: touch.view, window: window, event: event)
            let interaction = PressInteraction(
                phase: PressInteraction.phase(forTouch: touch.phase),
                kind: .untrackedWindowTouch,
                timestamp: touch.timestamp,
                target: target,
                sessionId: sessionId
            )
            continuation.yield(.press(interaction))
        }
    }
    
    private func processTouches(
        event: UIEvent,
        window: UIWindow,
        screen: (screenId: String?, screenName: String?),
        continuation: AsyncStream<InteractionCaptureItem>.Continuation
    ) {
        guard let touches = event.allTouches else { return }
        let sessionId = sessionIdProvider()
        // `screen` was sampled on the main thread BEFORE the app handled the event (see `start`), so
        // it reflects the screen the touch landed on even if a tap handler navigated synchronously
        // during dispatch.
        for touch in touches {
            let target: TouchTarget?
            if touch.phase == .began || touch.phase == .ended {
                target = targetResolver.resolve(view: touch.view, window: window, event: event)
            } else {
                target = nil
            }
            
            let touchSample = TouchSample(
                touch: touch,
                window: window,
                target: target,
                sessionId: sessionId,
                screenId: screen.screenId,
                screenName: screen.screenName
            )
            continuation.yield(.touch(touchSample))
        }
    }
    
    private func processPresses(
        event: UIEvent,
        window: UIWindow,
        continuation: AsyncStream<InteractionCaptureItem>.Continuation
    ) {
        guard let pressesEvent = event as? UIPressesEvent else { return }
        let sessionId = sessionIdProvider()
        for press in pressesEvent.allPresses {
            guard press.phase == .began else { continue }
            let target = targetResolver.resolve(press: press, window: window)
            let interaction = PressInteraction(press: press, target: target, sessionId: sessionId)
            if case .other = interaction.kind { continue }
            
            continuation.yield(.press(interaction))
        }
    }
}
