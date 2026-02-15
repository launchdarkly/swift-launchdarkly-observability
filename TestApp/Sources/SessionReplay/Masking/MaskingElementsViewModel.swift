import SwiftUI
import LaunchDarklyObservability
import LaunchDarklySessionReplay

final class MaskingElementsViewModel: ObservableObject {
    var screenCaptureService = ImageCaptureService(options: SessionReplayOptions())
    var capturedImage: UIImage?
    @Published var isImagePresented: Bool = false
    
    @MainActor
    func captureShapShot() {
        screenCaptureService.captureUIImage{ image in
            self.capturedImage = image
            self.isImagePresented = true
        }
    }
}
