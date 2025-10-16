import Foundation
import OpenTelemetryApi

struct SpanError: SpanException {
    private let error: Error
    var type: String {
        String(describing: error)
    }
    
    var message: String? {
        var string = ""
        dump(error, to: &string)
        return "\(String(describing: error))\n\(string)"
    }
    
    var stackTrace: [String]? {
        Thread.callStackSymbols
    }
    
    init(error: Error) {
        self.error = error
    }
}
