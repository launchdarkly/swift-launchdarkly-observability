/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Tab based app structure.
 */

#if os(iOS)

import SwiftUI

struct AppTabNavigation: View {
    static var pullPushLoop = 0
    @Environment(\.dismiss) var dismiss
    
    enum Tab {
        case menu
        case favorites
        case rewards
        case recipes
    }
    
    @State private var selection: Tab = .menu
    
    init(selection: Tab = .menu) {
        self.selection = selection
    }
    
    var body: some View {
        TabView(selection: $selection) {
            NavigationView {
                SmoothieMenu()
            }
            .tabItem {
                let menuText = Text("Menu", comment: "Smoothie menu tab title")
                Label {
                    menuText
                } icon: {
                    Image(systemName: "list.bullet")
                }.accessibility(label: menuText)
            }
            .tag(Tab.menu)
            
            NavigationView {
                FavoriteSmoothies()
            }
            .tabItem {
                Label {
                    Text("Favorites",
                         comment: "Favorite smoothies tab title")
                } icon: {
                    Image(systemName: "heart.fill")
                }
            }
            .tag(Tab.favorites)
            
            
#if EXTENDED_ALL
            NavigationView {
                RewardsView()
            }
            .tabItem {
                Label {
                    Text("Rewards",
                         comment: "Smoothie rewards tab title")
                } icon: {
                    Image(systemName: "seal.fill")
                }
            }
            .tag(Tab.rewards)
            
            NavigationView {
                RecipeList()
            }
            .tabItem {
                Label {
                    Text("Recipes",
                         comment: "Smoothie recipes tab title")
                } icon: {
                    Image(systemName: "book.closed.fill")
                }
            }
            .tag(Tab.recipes)
#endif
        }            .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Self.pullPushLoop = 1000
                    dismiss()
                }) {
                    if Self.pullPushLoop == 0 {
                        Image(systemName: "arrow.left.arrow.right")
                    } else {
                        Text("\(Self.pullPushLoop)")
                    }
                }
            }
        }.onAppear {
            if Self.pullPushLoop > 0 {
                Self.pullPushLoop -= 1
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.1...1.5)) {
                    self.dismiss()
                }
            }
        }
    }
}

struct AppTabNavigation_Previews: PreviewProvider {
    static var previews: some View {
        AppTabNavigation()
    }
}

#endif
