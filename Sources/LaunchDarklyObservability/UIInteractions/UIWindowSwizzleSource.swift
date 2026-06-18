#if canImport(UIKit)

import UIKit.UIWindow

final class UIWindowSwizzleSource: UIEventSource, AnyObject {
    typealias SendEventRef = @convention(c) (UIWindow, Selector, UIEvent) -> Void
    private static let sendEvenSelector = #selector(UIWindow.sendEvent(_:))
    private var isActive: Bool = false
    private var originalIMP: IMP?
    
    init() {
    }
    
    func start(handler: @escaping (UIEvent, UIWindow, () -> Void) -> Void) {
        guard !isActive else { return }
        
        guard let originalMethod = class_getInstanceMethod(UIWindow.self, UIWindowSwizzleSource.sendEvenSelector) else { return }
        
        let swizzledSendEventBlock: @convention(block) (UIWindow, UIEvent) -> Void = { [weak self] window, event in
            guard let self else { return }
            
            // Forward to the app's original `sendEvent`. Handed to the handler as a thunk so the
            // handler decides when the app processes the event relative to its own capture work.
            let dispatchOriginal: () -> Void = { [weak self] in
                guard let self, let originalIMP = self.originalIMP else { return }
                let castedIMP = unsafeBitCast(originalIMP, to: SendEventRef.self)
                castedIMP(window, UIWindowSwizzleSource.sendEvenSelector, event)
            }
            
            handler(event, window, dispatchOriginal)
        }
        
        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(swizzledSendEventBlock, to: AnyObject.self))
        originalIMP = method_setImplementation(originalMethod, swizzledIMP)
        isActive = true
    }
    
    func stop() {
        guard isActive else { return }
        
        disable()
    }
    
    private func disable() {
        guard let method = class_getInstanceMethod(UIWindow.self, UIWindowSwizzleSource.sendEvenSelector),
        let originalIMP else { return }
        
        _ = method_setImplementation(method, originalIMP)
        isActive = false
    }
}

#endif
