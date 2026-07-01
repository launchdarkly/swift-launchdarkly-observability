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
        case overlayTiles(layers: Int = 10, backtracking: Bool = true)
    }
    
    public enum RenderStrategy {
        case drawHierarchy
        case drawLayers
    }
    
    public var isEnabled: Bool
    /// Probability from `0.0` to `1.0` that Session Replay starts when enabled.
    /// Values less than or equal to zero never start; values greater than or equal to one always start.
    public var sampleRate: Double
    public var compression: CompressionMethod = .overlayTiles()
    /// Target capture rate in frames per second.
    public var frameRate: Double
    /// Render scale applied when capturing frames. Usually from 1-4, where
    /// `1` = 160 DPI. Higher values capture at greater resolution. Defaults to `1.0`.
    public var scale: CGFloat
    public var renderStrategy: RenderStrategy
    public var privacy = PrivacyOptions()
    public var log: OSLog
    
    public init(isEnabled: Bool = true,
                sampleRate: Double = 1.0,
                serviceName: String = "sessionreplay-swift",
                privacy: PrivacyOptions = PrivacyOptions(),
                compression: CompressionMethod = .overlayTiles(),
                frameRate: Double = 1.0,
                scale: CGFloat = 1.0,
                renderStrategy: RenderStrategy = .drawHierarchy,
                log: OSLog = OSLog(subsystem: "com.launchdarkly", category: "LaunchDarklySessionReplayPlugin")) {
        self.isEnabled = isEnabled
        self.sampleRate = sampleRate
        self.privacy = privacy
        self.compression = compression
        self.frameRate = frameRate
        self.scale = scale
        self.renderStrategy = renderStrategy
        self.log = log
    }
}
