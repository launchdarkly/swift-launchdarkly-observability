import Foundation
import LaunchDarklyObservability

struct IdentifyItemPayload: EventQueueItemPayload {
    let attributes: [String: String]
    var timestamp: TimeInterval

    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }
    
    func cost() -> Int {
        attributes.count * 100
    }
}

extension IdentifyItemPayload {
    // Using main thread to access to ldContext
    @MainActor
    init(options: Options, ldContext: LDContext? = nil, timestamp: TimeInterval) {
        var attributes: [String: String] = options.resourceAttributes.compactMapValues {
            switch $0 {
            case .array, .set, .boolArray, .intArray, .doubleArray, .stringArray:
                return nil
            case .string(let v):
                return v
            case .bool(let v):
                return v.description
            case .int(let v):
                return String(v)
            case .double(let v):
                return String(v)
            }
        }
        
        var canonicalKey = ldContext?.fullyQualifiedKey() ?? "unknown"
        var ldContextMap = ldContext?.contextKeys()
        if let ldContextMap {
            for (k, v) in ldContextMap {
                attributes[k] = v
            }
        }
        
        var contextFriendlyName: String? = nil
        if let contextFriendlyNameUnwrapped = options.contextFriendlyName, contextFriendlyNameUnwrapped.isNotEmpty {
            contextFriendlyName = contextFriendlyNameUnwrapped
        } else if let ldContext, ldContext.isMulti() == true, let userKey = ldContextMap?["user"], !userKey.isEmpty {
            // For multi-kind contexts, prefer the "user" kind key as a friendly name if present.
            // Note: `contextKeys()` maps kinds → keys, not attributes like "email".
            contextFriendlyName = userKey
        }
        attributes["key"] = contextFriendlyName ?? canonicalKey
        attributes["canonicalKey"] = canonicalKey
        
        self.attributes = attributes
        self.timestamp = timestamp
    }
}

