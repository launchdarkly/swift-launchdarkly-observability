#if os(iOS)

import SwiftUI
import UIKit
import LaunchDarklyObservability

/// Presents the system camera UI (`UIImagePickerController` with `sourceType = .camera`).
///
/// The purpose of this screen is to reproduce a fatal `EXC_BREAKPOINT` crash that occurs on
/// iOS 26 when LaunchDarkly Session Replay is enabled and the system camera UI is on screen:
///
///     Fatal error: Use of unimplemented initializer 'init(layer:)' for class
///     'CameraUI.ModeLoupeLayer'
///
/// While Session Replay captures a frame it walks the on-screen layer tree and copies layers.
/// The private `CameraUI.ModeLoupeLayer` (the zoom / mode loupe shown in the camera controls)
/// does not implement `init(layer:)`, so the copy traps.
///
/// Requires running on a physical device with a camera (the Simulator has no camera source).
struct CameraSampleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                CameraPickerRepresentable {
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                CameraUnavailableView {
                    dismiss()
                }
            }
        }
        .trackScreen("Camera Sample")
    }
}

/// Wraps `UIImagePickerController` so the full system camera UI (including the `ModeLoupeLayer`
/// zoom / mode controls) is presented on screen.
private struct CameraPickerRepresentable: UIViewControllerRepresentable {
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onFinish()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish()
        }
    }
}

private struct CameraUnavailableView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera Unavailable")
                .font(.headline)
            Text("Run on a physical device with a camera to reproduce the CameraUI.ModeLoupeLayer crash.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

#Preview {
    CameraSampleView()
}

#endif
