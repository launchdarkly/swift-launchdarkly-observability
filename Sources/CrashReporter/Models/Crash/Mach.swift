import Foundation

// MARK: - Mach
public struct Mach: Codable, Hashable, Sendable {
    public let exception: Int
    public let exceptionName: String
    public let code: Int
    public let codeName: String
    public let subcode: Int

    public enum CodingKeys: String, CodingKey {
        case exception = "exception"
        case exceptionName = "exception_name"
        case code = "code"
        case codeName = "code_name"
        case subcode = "subcode"
    }

    public init(exception: Int, exceptionName: String, code: Int, codeName: String, subcode: Int) {
        self.exception = exception
        self.exceptionName = exceptionName
        self.code = code
        self.codeName = codeName
        self.subcode = subcode
    }
}
