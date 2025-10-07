import Foundation

enum CommonOTelPath {
    static let logsPath = "/v1/logs"
    static let metricsPath = "/v1/metrics"
    static let tracesPath = "/v1/traces"
}

enum CommonOTelConfiguration {
    static let flushTimeout: TimeInterval = 5
}
