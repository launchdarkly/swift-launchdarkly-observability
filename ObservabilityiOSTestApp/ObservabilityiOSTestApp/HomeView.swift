import SwiftUI
import LaunchDarkly
import LaunchDarklyObservability

private let featureFlag = "new-home-experience"
struct HomeView: View {
    @State private var isNewExperience = Optional<Bool>.none
    
    var body: some View {
        NavigationStack {
            if isNewExperience == true {
                HomeNewView()
            } else if isNewExperience == false {
                HomeOldView()
            } else {
                Text("Default Home View")
            }
        }
        .onAppear {
            isNewExperience = LDClient.get()?.boolVariation(
                forKey: featureFlag,
                defaultValue: false
            )
        }
    }
}
