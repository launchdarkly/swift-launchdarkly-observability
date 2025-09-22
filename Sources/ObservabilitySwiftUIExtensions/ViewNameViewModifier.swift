import Foundation
import os
import SwiftUI

import OpenTelemetryApi

import LaunchDarklyObservability

public struct ViewNameViewModifier: ViewModifier {
    public let screenName: String
    public let attributes: [String: AttributeValue]?
    
    public init(screenName: String, attributes: [String: AttributeValue]? = nil) {
        self.screenName = screenName
        self.attributes = attributes
    }
    
    public func body(content: Content) -> some View {
        content
            .onDisappear {
                let logAttributes = self.attributes ?? [String: AttributeValue]()
                LDObserve.shared.recordLog(
                    message: "on Disappear \(self.screenName ?? String(describing: self))",
                    severity: .info,
                    attributes: [
                        "screen.name": .string(self.screenName),
                    ].merging(logAttributes) { _, inbound in inbound }
                )
            }
            .onAppear {
                let logAttributes = self.attributes ?? [String: AttributeValue]()
                LDObserve.shared.recordLog(
                    message: "on Appear \(self.screenName ?? String(describing: self))",
                    severity: .info,
                    attributes: [
                        "screen.name": .string(self.screenName),
                    ].merging(logAttributes) { _, inbound in inbound }
                )
            }
    }
}


extension View {
    public func logScreenName(_ screenName: String, attributes: [String: AttributeValue]? = nil) -> some View {
        modifier(ViewNameViewModifier(screenName: screenName, attributes: attributes))
    }
}


