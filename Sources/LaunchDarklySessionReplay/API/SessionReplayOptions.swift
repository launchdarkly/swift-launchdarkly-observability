import Foundation
import OSLog

public struct SessionReplayOptions {
    
    public struct PrivacyOptions {
        public var maskTextInputs: Bool
        public var maskWebViews: Bool
        public var maskLabels: Bool
        public var maskImages: Bool
        
        public var maskUIViews: [AnyClass]
        public var unmaskUIViews: [AnyClass]
        public var ignoreUIViews: [AnyClass]
        
        public var maskAccessibilityIdentifiers: [String]
        public var unmaskAccessibilityIdentifiers: [String]
        public var ignoreAccessibilityIdentifiers: [String]
        
        public var minimumAlpha: CGFloat
        
        public init(maskTextInputs: Bool = true,
                    maskWebViews: Bool = false,
                    maskLabels: Bool = false,
                    maskImages: Bool = false,
                    maskUIViews: [AnyClass] = [],
                    unmaskUIViews: [AnyClass] = [],
                    ignoreUIViews: [AnyClass] = [],
                    maskAccessibilityIdentifiers: [String] = [],
                    unmaskAccessibilityIdentifiers: [String] = [],
                    ignoreAccessibilityIdentifiers: [String] = [],
                    minimumAlpha: CGFloat = 0.02) {
            self.maskTextInputs = maskTextInputs
            self.maskWebViews = maskWebViews
            self.maskLabels = maskLabels
            self.maskImages = maskImages
            self.maskUIViews = maskUIViews
            self.unmaskUIViews = unmaskUIViews
            self.ignoreUIViews = ignoreUIViews
            self.maskAccessibilityIdentifiers = maskAccessibilityIdentifiers
            self.unmaskAccessibilityIdentifiers = unmaskAccessibilityIdentifiers
            self.ignoreAccessibilityIdentifiers = ignoreAccessibilityIdentifiers
            self.minimumAlpha = minimumAlpha
        }
    }
    
    public enum CompressionMethod {
        case screenImage
        case overlayTiles(layers: Int = 10)
    }
    
    public var isEnabled: Bool
    public var compression: CompressionMethod = .overlayTiles()
    public var serviceName: String
    public var privacy = PrivacyOptions()
    public var log: OSLog
    
    public init(isEnabled: Bool = true,
                serviceName: String = "sessionreplay-swift",
                privacy: PrivacyOptions = PrivacyOptions(),
                compression: CompressionMethod = .overlayTiles(),
                log: OSLog = OSLog(subsystem: "com.launchdarkly", category: "LaunchDarklySessionReplayPlugin")) {
        self.isEnabled = isEnabled
        self.serviceName = serviceName
        self.privacy = privacy
        self.compression = compression
        self.log = log
    }
}
