//
//  MaskingElementsView.swift
//  TestApp
//
//  Created by Andrey Belonogov on 10/15/25.
//


import SwiftUI
import LaunchDarklyObservability

struct NumberPadView: View {
    /// Set when the screen is presented outside of a SwiftUI presentation, where `dismiss` has no effect.
    var onClose: (() -> Void)?
    @State var text = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                NumberPatternGrid { sequence in 
                }
#if os(iOS)
                .background(Color(.systemBackground))
                #endif
            }
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("Number Pad (SwiftUI)")
            .toolbar {
                Button {
                    if let onClose {
                        onClose()
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "checkmark")
                }
            }
        }
        .trackScreen("Number Pad (SwiftUI)")
    }
}

#Preview {
    NumberPadView()
}


