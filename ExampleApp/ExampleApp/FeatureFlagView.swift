import SwiftUI
import LaunchDarkly

struct FeatureFlagView: View {
    private let featureFlag = "new-home-experience"
    @State private var isNewExperience = Optional<Bool>.none
    
    var body: some View {
        Group {
            if let isNewExperience {
                Text("Feature flag is: \(isNewExperience)")
            } else {
                Text("Feature flag is nil...")
            }
        }
        .font(.title)
        .bold()
        .onAppear {
            isNewExperience = LDClient.get()?.boolVariation(
                forKey: featureFlag,
                defaultValue: false
            )
        }
    }
  
}
