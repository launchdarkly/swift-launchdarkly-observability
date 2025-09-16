import Foundation

extension CGFloat {
    public func toString() -> String {
        String(format: "%.2f", self)
    }
}
