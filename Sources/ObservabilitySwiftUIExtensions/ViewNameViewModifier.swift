import Foundation
import os
import SwiftUI

import OpenTelemetryApi

import LaunchDarklyObservability

public struct ViewNameViewModifier: ViewModifier {
    public let viewName: String
    public let attributes: [String: AttributeValue]?
    
    public init(viewName: String, attributes: [String: AttributeValue]? = nil) {
        self.viewName = viewName
        self.attributes = attributes
    }
    
    public func body(content: Content) -> some View {
        content
            .onDisappear {
                let logAttributes = self.attributes ?? [String: AttributeValue]()
                LDObserve.shared.recordLog(
                    message: "on Disappear \(self.viewName)",
                    severity: .info,
                    attributes: [
                        "screen.name": .string(self.viewName),
                    ].merging(logAttributes) { _, inbound in inbound }
                )
            }
            .onAppear {
                let logAttributes = self.attributes ?? [String: AttributeValue]()
                LDObserve.shared.recordLog(
                    message: "on Appear \(self.viewName)",
                    severity: .info,
                    attributes: [
                        "screen.name": .string(self.viewName),
                    ].merging(logAttributes) { _, inbound in inbound }
                )
            }
    }
}


extension View {
    public func logViewName(_ viewName: String, attributes: [String: AttributeValue]? = nil) -> some View {
        modifier(ViewNameViewModifier(viewName: viewName, attributes: attributes))
    }
}


