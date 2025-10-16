//
//  MaskingElementsView.swift
//  TestApp
//
//  Created by Andrey Belonogov on 10/15/25.
//


import SwiftUI

struct NumberPadView: View {
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
    NumberPadView()
}


