import Foundation

struct Env {
    static var mobileKey: String {
        ProcessInfo.processInfo.environment["MOBILE_KEY"] ?? ""
    }
    
    static var otelHost: String {
        ProcessInfo.processInfo.environment["OPTL_ENDPOINT"] ?? ""
    }
}
