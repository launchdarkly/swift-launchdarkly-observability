import UIKit

@objcMembers
public class ObjcLDMasking: NSObject {
    // Use explicit selectors so we control the Obj-C names.
    @objc(maskView:)
    public static func mask(view: UIView) {
        view.ldMask()
    }

    @objc(unmaskView:)
    public static func unmask(view: UIView) {
        view.ldUnmask()
    }

    @objc(ignoreView:)
    public static func ignore(view: UIView) {
        view.ldIgnore()
    }
}
