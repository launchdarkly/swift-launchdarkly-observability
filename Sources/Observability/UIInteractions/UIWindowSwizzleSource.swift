#if canImport(UIKit)

import UIKit.UIWindow

final class UIWindowSwizzleSource: UIEventSource {
    typealias SendEventRef = @convention(c) (UIWindow, Selector, UIEvent) -> Void
    private static let sendEvenSelector = #selector(UIWindow.sendEvent(_:))
    private var yield: (TouchSample) -> Void
    private var isActive: Bool = false
    private let receiverChecker = UIEventReceiverChecker()
    private let targetResolver: TargetResolving
    private var originalIMP: IMP?
    
    init(targetResolver: TargetResolving, yield: @escaping (UIWindow, UIEvent) -> Void) {
        self.targetResolver = targetResolver
        self.yield = yield
    }
    
    func start() {
        guard !isActive else { return }
        
        inject()
    }
    
    func stop() {
        guard isActive else { return }
        
        disable()
    }
    
    private func inject() {
        guard let originalMethod = class_getInstanceMethod(UIWindow.self, sendEvenSelector) else { return }
        
        let swizzledSendEventBlock: @convention(block) (UIWindow, UIEvent) -> Void = { window, event in
            if let originalIMP = originalIMP {
                let castedIMP = unsafeBitCast(originalIMP, to: SendEventRef.self)
                castedIMP(window, sendEvenSelector, event)
            }
            
            guard receiverChecker.shouldTrack(window) else {
                return
            }
            
            guard let interaction = targetResolver.resolve() else {
                return
            }
            
            if let touches = event.allTouches() {
                for t in touches {
                    yield(TouchSample(touch: t, window: window))
                }
            }
        }
        
        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(swizzledSendEventBlock, to: AnyObject.self))
        originalIMP = method_setImplementation(originalMethod, swizzledIMP)
    }
    
    private func disable() {
        guard let method = class_getInstanceMethod(UIWindow.self, UIWindowSwizzleSource.sendEvenSelector),
        let originalIMP else { return }
        
        _ = method_setImplementation(method, originalIMP)
    }
}

#endif
