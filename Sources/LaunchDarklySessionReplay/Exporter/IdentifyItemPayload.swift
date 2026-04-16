import Foundation
import LaunchDarklyObservability

struct IdentifyItemPayload: EventQueueItemPayload {
    let attributes: [String: String]
    var timestamp: TimeInterval
    let sessionId: String

    var exporterClass: AnyClass {
        SessionReplayExporter.self
    }

    func cost() -> Int {
        attributes.count * 100
    }
}

extension IdentifyItemPayload {
    /// Builds the final attribute dictionary from resource/session attributes,
    /// context keys, canonical key, and the optional friendly-name override.
    private static func buildAttributes(
        options: ObservabilityOptions,
        sessionAttributes: [String: AttributeValue]?,
        contextKeys: [String: String],
        canonicalKey: String
    ) -> [String: String] {
        // Keep the existing value from ObservabilityOptions if duplicate key is found;
        // client has precedence over session attribute.
        var attributes: [String: String] = options.resourceAttributes
            .merging(sessionAttributes ?? [:], uniquingKeysWith: { (current, _) in current })
            .compactMapValues {
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

        for (k, v) in contextKeys {
            attributes[k] = v
        }

        var contextFriendlyName: String? = nil
        if let contextFriendlyNameUnwrapped = options.contextFriendlyName, contextFriendlyNameUnwrapped.isNotEmpty {
            contextFriendlyName = contextFriendlyNameUnwrapped
        }
        attributes["key"] = contextFriendlyName ?? canonicalKey
        attributes["canonicalKey"] = canonicalKey

        return attributes
    }

    @MainActor
    init(options: ObservabilityOptions, sessionAttributes: [String: AttributeValue]?, ldContext: LDContext? = nil, timestamp: TimeInterval, sessionId: String) {
        let canonicalKey = ldContext?.fullyQualifiedKey() ?? "unknown"
        let contextKeys = ldContext?.contextKeys() ?? [:]

        self.attributes = Self.buildAttributes(
            options: options,
            sessionAttributes: sessionAttributes,
            contextKeys: contextKeys,
            canonicalKey: canonicalKey
        )
        self.timestamp = timestamp
        self.sessionId = sessionId
    }

    /// Proxy-friendly initialiser that accepts pre-extracted context keys
    /// instead of LDContext, so the MAUI bridge can call it with simple types.
    init(options: ObservabilityOptions, sessionAttributes: [String: AttributeValue]?, contextKeys: [String: String], canonicalKey: String, timestamp: TimeInterval, sessionId: String) {
        self.attributes = Self.buildAttributes(
            options: options,
            sessionAttributes: sessionAttributes,
            contextKeys: contextKeys,
            canonicalKey: canonicalKey
        )
        self.timestamp = timestamp
        self.sessionId = sessionId
    }
}

