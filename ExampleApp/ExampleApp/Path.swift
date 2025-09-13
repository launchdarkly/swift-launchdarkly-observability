import SwiftUI

enum Path: Hashable {
    case home
    case manualInstrumentation
    case automaticInstrumentation
    case evaluation
}

@Observable final class Browser {
    var path = NavigationPath()
    
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
