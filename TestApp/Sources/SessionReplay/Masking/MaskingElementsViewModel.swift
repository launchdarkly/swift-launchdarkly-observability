import SwiftUI
import LaunchDarkly
import LaunchDarklySesionReplay

final class MaskingElementsViewModel: ObservableObject {
    var screenCaptureService = ScreenCaptureService(options: SessionReplayOptions())
    var capturedImage: CapturedImage?
    @Published var isImagePresented: Bool = false
    
    func captureScreenShot() {
        guard let image = screenCaptureService.captureUIImage() else {
            return
        }
        
        self.capturedImage = image
        self.isImagePresented = true
    }
}

