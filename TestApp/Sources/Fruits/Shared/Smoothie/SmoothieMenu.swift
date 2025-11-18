/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The menu tab or content list that includes all smoothies.
*/
#if os(iOS)

import SwiftUI

struct SmoothieMenu: View {
    
    var body: some View {
        let menuText = if AppTabNavigation.pullPushLoop == 0  {
            Text("Menu", comment: "Title of the 'menu' app section showing the menu of available smoothies")
        } else {
            Text("Menu \(AppTabNavigation.pullPushLoop)")
        }
        SmoothieList(smoothies: Smoothie.all())
            .navigationTitle(menuText)
    }
    
}

struct SmoothieMenu_Previews: PreviewProvider {
    static var previews: some View {
        SmoothieMenu()
            .environmentObject(Model())
    }
}

#endif
