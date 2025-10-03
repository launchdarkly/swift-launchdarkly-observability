import Foundation

extension CGRect {
    func enclosing(with other: CGRect) -> CGRect {
        var rect = self
        if other.minX < rect.minX {
            rect.origin.x = other.minX
        }
        if other.minY < rect.minY {
            rect.origin.y = other.minY
        }
        if other.maxX > rect.maxX {
            rect.size.width = other.maxX - rect.minX
        }
        if other.maxY > rect.maxY {
            rect.size.height = other.maxY - rect.minY
        }
        return rect
    }
}
