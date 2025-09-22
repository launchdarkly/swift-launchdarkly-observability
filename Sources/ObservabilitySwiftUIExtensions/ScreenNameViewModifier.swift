import Foundation
import SwiftUI

import OpenTelemetryApi

import LaunchDarklyObservability

public struct ScreenNameViewModifier: ViewModifier {
    public let screenName: String?
    public let attributes: [String: AttributeValue]?
    
    public init(screenName: String? = nil, attributes: [String: AttributeValue]? = nil) {
        self.screenName = screenName
        self.attributes = attributes
    }
    
    public func body(content: Content) -> some View {
        content.onAppear {
            let logAttributes = self.attributes ?? [String: AttributeValue]()
            
            LDObserve.shared.recordLog(
                message: "Appeared \(self.screenName ?? String(describing: self))",
                severity: .info,
                attributes: [
                    "screen.name": .string(self.screenName ?? String(describing: self)),
                    "screen.class": .string(String(describing: self))
                ].merging(logAttributes) { _, inbound in inbound }
            )
        }
    }
}


extension View {
    public func logScreenName(_ screenName: String? = nil, attributes: [String: AttributeValue]? = nil) -> some View {
        modifier(ScreenNameViewModifier(screenName: screenName, attributes: attributes))
    }
}
