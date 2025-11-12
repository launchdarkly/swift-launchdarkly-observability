import Foundation
import LaunchDarkly

extension LDClient {
    private enum ObservabilityConstants {
        static var associatedObjectKey: Int = 0
    }
    
    public var observabilityService: Observe? {
        get {
            objc_getAssociatedObject(self, &ObservabilityConstants.associatedObjectKey) as? Observe
        } set {
            objc_setAssociatedObject(self, &ObservabilityConstants.associatedObjectKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}
