//
//  SwiftUIView.swift
//  swift-launchdarkly-observability
//
//  Created by Andrey Belonogov on 9/28/25.
//

import SwiftUI
import SessionReplay
import UIKit

struct CapturedImageView: View {
    let image: UIImage
    
    init(image: UIImage) {
        self.image = image
    }
    
    var body: some View {
        Image(uiImage: image)
    }
}

#Preview {
    let image = UIImage(named: "smoothie/recipes-background")!
//    let image = UIImage(systemName: "heart.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 100))!
    CapturedImageView(image: image)
}
