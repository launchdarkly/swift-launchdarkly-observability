import SwiftUI

enum Path: Hashable {
    case home
    case manualInstrumentation
    case stressSamples
    case automaticInstrumentation
    case evaluation
}

final class Browser: ObservableObject {
    @Published var path = NavigationPath()
    
    func navigate(to path: Path) {
        self.path.append(path)
    }
    
    func pop() {
        self.path.removeLast()
    }
    
    func reset() {
        self.path = NavigationPath()
    }
}
