import SwiftUI

struct ScreenshotSectionView: View {
    @StateObject var viewModel = ScreenshotViewModel()
    
    var body: some View {
        Button {
            viewModel.sendScreenShot()
        } label: {
            Text("Send screenshot")
        }.buttonStyle(.borderedProminent)

  
    }
}

#Preview {
    ScreenshotSectionView()
}
