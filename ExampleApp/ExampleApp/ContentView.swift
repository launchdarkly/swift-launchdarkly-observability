//
//  ContentView.swift
//  ExampleApp
//
//  Created by Mario Canto on 04/09/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var browser: Browser
    
    var body: some View {
        VStack(spacing: 32) {
            Button {
                fatalError()
            } label: {
                Text("Crash")
            }
            Button {
                browser.navigate(to: .automaticInstrumentation)
            } label: {
                Text("Automatic Instrumentation")
            }
            Button {
                browser.navigate(to: .evaluation)
            } label: {
                Text("Flag evaluation")
            }
            Button {
                browser.navigate(to: .manualInstrumentation)
            } label: {
                Text("Manual Instrumentation")
            }
//            NetworkRequestView()
//            FeatureFlagView()
            Button {
                browser.navigate(to: .stressSamples)
            } label: {
                Text("Stress Samples")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
