//
//  SwiftUIView.swift
//  swift-launchdarkly-observability
//
//  Created by Andrey Belonogov on 9/28/25.
//

import SwiftUI

struct MaskingElementsView: View {
    @State var text = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                VStack(alignment: .leading) {
                    TextField("TexField", text: $text)
                        .keyboardType(.numberPad)
                        .border(Color.gray)
                        .frame(width: 200, height: 32)
                }
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Masking Elements (UIKit)")
            .toolbar {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                }
                SnapshotButton()
            }
        }
    }
}

#Preview {
    MaskingElementsView()
}
