import SwiftUI

struct SnapshotButton: View {
    @StateObject var viewModel = MaskingElementsViewModel()

    var body: some View {
        Button {
            viewModel.captureScreenShot()
        } label: {
            Image(systemName: "camera")
        }.sheet(isPresented: $viewModel.isImagePresented) {
            print(viewModel.isImagePresented)
            let image = viewModel.capturedImage!.image
            return CapturedImageView(image: image)
        }
    }
}

#Preview {
    SnapshotButton()
}
