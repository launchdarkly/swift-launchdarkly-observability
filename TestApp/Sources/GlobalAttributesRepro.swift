import LaunchDarklyObservability

/// Repro #1: global attributes (e.g. UTM params) on all telemetry.
///
/// `applyGlobalAttributes()` runs at launch before `LDClient.start`, so it also exercises
/// setting globals before the observability plugin has initialized. The existing Log and
/// span buttons print what to look for on the row they record.
enum GlobalAttributesRepro {
    static let globalAttributes: [String: AttributeValue] = [
        "utm_campaign": .string("spring_promo"),
        "utm_source": .string("email")
    ]

    static let perCallUtmSource = "per_call"

    static func applyGlobalAttributes() {
        LDObserve.shared.setAttributes(globalAttributes)
    }

    static func printSpanExpectation() {
        print("[#1] expect utm_campaign=spring_promo on this row")
    }

    static func printLogExpectation() {
        print("[#1] expect utm_campaign=spring_promo on this row")
        print("[#1] expect utm_source=\(perCallUtmSource) (per-call wins over global)")
    }
}
