import UIKit

final class UIEventReceiverChecker {
    let ignoreClasses: [String]
    var tracked = [ObjectIdentifier : Bool]()
    
    init(ignoreClasses: [String] = ["UIRemoteKeyboardWindow", "UITextEffectsWindow"]) {
        self.ignoreClasses = ignoreClasses
    }
    
    func shouldTrack(_ receiver: AnyObject) -> Bool {
        if let result = tracked[ObjectIdentifier(receiver)] {
            return result
        }
        
        let receiverClass = String(describing: type(of: receiver))
        let result = ignoreClasses.allSatisfy { !receiverClass.contains($0) }
        tracked[ObjectIdentifier(receiver)] = result
        return result
    }
}
