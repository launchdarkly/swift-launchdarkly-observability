import Foundation

struct Env {
    /// Provide 
    static var mobileKey: String {
        ProcessInfo.processInfo.environment["MOBILE_KEY"] ?? ""
    }
    
    static var otelHost: String {
        ProcessInfo.processInfo.environment["OPTL_ENDPOINT"] ?? ""
    }
}

/*
struct Env {
    /// Provide
    static var mobileKey: String {
        guard let dict = Bundle.main.infoDictionary else {
            return ""
        }
        
        return dict["MOBILE_KEY"] as? String ?? ""
    }
    
    static var otelHost: String {
        guard let dict = Bundle.main.infoDictionary else {
            return ""
        }
        
        return dict["OPTL_ENDPOINT"] as? String ?? ""
    }
}
*/
