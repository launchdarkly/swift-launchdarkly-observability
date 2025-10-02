import Foundation

public struct SessionReplayOptions {
    
    public struct PrivacySettings {
        public var maskTextInputs: Bool = true
        public var maskLabels: Bool = false
        public var maskImages: Bool = false
                
        public var maskUIViews: [AnyClass] = []
        public var ignoreUIViews: [AnyClass] = []
       
        public var maskAccessibilityIdentifiers: [String] = []
        public var ignoreAccessibilityIdentifiers: [String] = []
        
        public var minimumAlpha = 0.02
        public var maskiOS26TypeIds = ["CameraUI.ChromeSwiftUIView"]
    }
    
    public var privacySettings = PrivacySettings()
    
    public init() {
    }
}
