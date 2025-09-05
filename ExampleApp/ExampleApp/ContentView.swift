//
//  ContentView.swift
//  ExampleApp
//
//  Created by Mario Canto on 04/09/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 32) {
            Button {
                fatalError()
            } label: {
                Text("Crash")
            }
            NetworkRequestView()
            FeatureFlagView()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
