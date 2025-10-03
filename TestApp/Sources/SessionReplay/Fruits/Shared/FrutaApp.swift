/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The single entry point for the Fruta app on iOS and macOS.
*/

import SwiftUI
/// - Tag: SingleAppDefinitionTag

struct FrutaAppView: View {
    @StateObject private var model = Model()
    
    var body: some View {
       // WindowGroup {
            FruitContentView().overlay(alignment: .topTrailing) {
                SnapshotButton()
            }
                .environmentObject(model)
        //}
       // .commands {
       //     SidebarCommands()
       //     SmoothieCommands(model: model)
       // }
    }
}
