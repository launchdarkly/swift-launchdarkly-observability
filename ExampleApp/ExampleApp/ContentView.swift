//
//  ContentView.swift
//  ExampleApp
//
//  Created by Mario Canto on 04/09/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(Browser.self) var browser
    
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
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
