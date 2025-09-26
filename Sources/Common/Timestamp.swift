import Foundation

extension Date {
    public var millisecondsSince1970: Int64 {
        Int64(timeIntervalSince1970 * 1000.0)
    }
}

extension TimeInterval {
    public var milliseconds: Int64 {
        Int64(self * 1000.0)
    }
}
