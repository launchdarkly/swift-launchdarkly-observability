import UIKit

public final class UIWindowSendEvent {
    typealias SendEventRef = @convention(c) (UIWindow, Selector, UIEvent) -> Void
    private static let sendEvenSelector = #selector(UIWindow.sendEvent(_:))
    
    public static func inject(
        into subclasses: [UIWindow.Type] = [],
        block: @escaping (UIWindow, UIEvent) -> Void
    ) {
        guard let originalMethod = class_getInstanceMethod(UIWindow.self, sendEvenSelector) else { return }
    
        var originalIMP = Optional<IMP>.none
        
        let swizzledSendEventBlock: @convention(block) (UIWindow, UIEvent) -> Void = { window, event in
            if let originalIMP = originalIMP {
                let castedIMP = unsafeBitCast(originalIMP, to: SendEventRef.self)
                castedIMP(window, sendEvenSelector, event)
            }

            guard !subclasses.isEmpty else {
                return block(window, event)
            }
            if UIWindowSendEvent.shouldInject(into: window, subclasses: subclasses) {
                block(window, event)
            }
        }
        
        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(swizzledSendEventBlock, to: AnyObject.self))
        originalIMP = method_setImplementation(originalMethod, swizzledIMP)
    }
    
    private static func shouldInject(into receiver: Any, subclasses: [UIWindow.Type]) -> Bool {
        let ids = subclasses.map { ObjectIdentifier($0) }
        let receiverType = type(of: receiver)
        return ids.contains(ObjectIdentifier(receiverType))
    }
}
