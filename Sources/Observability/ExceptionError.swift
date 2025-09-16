import Foundation
import OpenTelemetryApi

struct ErrorSpanException: SpanException {
    private let error: Error
    var type: String {
        String(describing: error)
    }
    
    var message: String? {
        String(describing: error)
    }
    
    var stackTrace: [String]? {
        Thread.callStackSymbols
    }
    
    init(error: Error) {
        self.error = error
    }
}
