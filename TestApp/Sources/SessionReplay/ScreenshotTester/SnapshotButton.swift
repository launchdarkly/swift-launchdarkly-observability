import SwiftUI

struct SnapshotButton: View {
    @StateObject private var viewModel = MaskingElementsViewModel()

    var body: some View {
        Button {
            viewModel.captureShapShot()
        } label: {
            Image(systemName: "camera")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("a-snapshot")
        .sheet(isPresented: $viewModel.isImagePresented) {
            CapturedImageView(image: viewModel.capturedImage ?? UIImage())
        }
    }
}

#Preview {
    SnapshotButton()
}
