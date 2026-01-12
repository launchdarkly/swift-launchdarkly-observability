//
//  SwiftUIView.swift
//  swift-launchdarkly-observability
//
//  Created by Andrey Belonogov on 9/28/25.
//

import SwiftUI

struct MaskingElementsView: View {
    @State var text = ""
    @State var toggled: Bool = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                ZStack(alignment: .topLeading) {
                    TextViewRepresentable()
                        .frame(height: 100)
                        .ldMask()
                        .padding()
                        .ldMask()
//                    Text("PlaceholderPlaceholderPlaceholderPlaceholder")
//                        .frame(height: 200)
//                        .background(.yellow.opacity(0.3))
//                        .allowsHitTesting(false)
                }
                VStack(alignment: .leading) {
                    ScrollView {
                        Toggle("Toggle", isOn: $toggled).padding().ldMask().padding()
                        ScrollView {
                            ZStack(alignment: .topLeading) {
                                TextViewRepresentable()
                                    .frame(height: 100)
                                    .ldMask()
                                    .padding()
                                    .ldMask()
//                                Text("PlaceholderPlaceholderPlaceholderPlaceholder")
//                                    .background(.yellow.opacity(0.3))
//                                    .foregroundColor(.secondary)
                            }
                            Toggle("Toggle", isOn: $toggled).ldMask().padding()
                            TextField("TexField", text: $text)
                                .keyboardType(.numberPad)
                                .ldMask()
                                .border(Color.gray)
                                .frame(width: 200, height: 32)
                            ScrollView(.horizontal) {
                                HStack(alignment: .center) {
                                    Toggle("Toggle", isOn: $toggled).ldMask().padding()
                                    Button {
                                        dismiss()
                                    } label: {
                                        Image(systemName: "checkmark")
                                    }
                                    .background(.gray).ldMask()
                                    Spacer()
                              
                                    Button {
                                        dismiss()
                                    } label: {
                                        Text("Close")
                                    }.background(.clear).ldMask().overlay {
                                        TextViewRepresentable()
                                            .padding()
                                    }.ldMask()
                                }.ldMask()
                            }.ldMask()
                        }.ldMask()
                    }.ldMask()
                }.ldMask()
                Spacer()
                VStack {
                    
                }
            }.ldMask()
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("Masking Elements (UIKit)")
            .toolbar {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                }
                SnapshotButton()
            }.ldMask()
        }
    }
}

struct TextViewRepresentable: UIViewRepresentable {
    func updateUIView(_ uiView: UITextField, context: Context) {
        
    }
    
    public typealias Context = UIViewRepresentableContext<Self>

    public func makeUIView(context: Context) -> UITextField {
        let view = UITextField()
        view.text = "Hello, World!"
        view.sizeToFit()
        view.backgroundColor = .gray
        //view.isUserInteractionEnabled = false
        return view
    }
    
}



#Preview {
    MaskingElementsView()
}
