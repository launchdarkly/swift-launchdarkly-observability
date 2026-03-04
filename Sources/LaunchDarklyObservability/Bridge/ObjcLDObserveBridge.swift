import Foundation

@objc(LDObserveBridge)
public final class ObjcLDObserveBridge: NSObject {

    /// Obj-C friendly entry-point that MAUI can bind to.
    /// - Parameters:
    ///   - message: log message
    ///   - severity: numeric severity (maps to your Swift `Severity(rawValue:)`)
    ///   - attributes: Foundation types only (String, Bool, Int, Double, [..], NSDictionary/NSArray)
    @objc(recordLogWithMessage:severity:attributes:)
    public static func recordLog(message: String,
                                 severity: Int,
                                 attributes: [String: Any] = [:]) {
        // Map severity Int -> your Swift Severity. Choose a sensible default.
        let sev = Severity(rawValue: severity) ?? .info

        // Convert Foundation values to your AttributeValue using the existing init?(Any)
        var attrs: [String: AttributeValue] = [:]
        for (k, v) in attributes {
            if let av = AttributeValue(v) {
                attrs[k] = av
            } else {
                // Fallback: stringify unsupported types
                attrs[k] = .string(String(describing: v))
            }
        }

        LDObserve.shared.recordLog(message: message, severity: sev, attributes: attrs)
    }
    
}
