import Foundation
import OSLog

public struct SessionReplayOptions {
    
    public struct PrivacyOptions {
        public var maskTextInputs: Bool
        public var maskLabels: Bool
        public var maskImages: Bool
        
        public var maskUIViews: [AnyClass]
        public var ignoreUIViews: [AnyClass]
        
        public var maskAccessibilityIdentifiers: [String]
        public var ignoreAccessibilityIdentifiers: [String]
        
        public var minimumAlpha: CGFloat
        public var maskiOS26TypeIds = ["CameraUI.ChromeSwiftUIView"]
        
        public init(maskTextInputs: Bool = true,
                    maskLabels: Bool = false,
                    maskImages: Bool = false,
                    maskUIViews: [AnyClass] = [],
                    ignoreUIViews: [AnyClass] = [],
                    maskAccessibilityIdentifiers: [String] = [],
                    ignoreAccessibilityIdentifiers: [String] = [],
                    minimumAlpha: CGFloat = 0.02) {
            self.maskTextInputs = maskTextInputs
            self.maskLabels = maskLabels
            self.maskImages = maskImages
            self.maskUIViews = maskUIViews
            self.ignoreUIViews = ignoreUIViews
            self.maskAccessibilityIdentifiers = maskAccessibilityIdentifiers
            self.ignoreAccessibilityIdentifiers = ignoreAccessibilityIdentifiers
            self.minimumAlpha = minimumAlpha
        }
    }
    
    public var isEnabled: Bool
    public var serviceName: String
    public var privacy = PrivacyOptions()
    public var log: OSLog
    
    public init(isEnabled: Bool = true,
                serviceName: String = "sessionreplay-swift",
                privacy: PrivacyOptions = PrivacyOptions(),
                log: OSLog = OSLog(subsystem: "com.launchdarkly", category: "LaunchDarklySessionReplayPlugin")) {
        self.isEnabled = isEnabled
        self.serviceName = serviceName
        self.privacy = privacy
        self.log = log
    }
}
