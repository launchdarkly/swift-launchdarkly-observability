import SwiftUI
import UIKit

struct StoryboardRootView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let sb = UIStoryboard(name: "StoryboardiOS", bundle: .main)
        // Use the Initial VC, or use instantiateViewController(withIdentifier:) if you set an ID
        return sb.instantiateInitialViewController()!
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
