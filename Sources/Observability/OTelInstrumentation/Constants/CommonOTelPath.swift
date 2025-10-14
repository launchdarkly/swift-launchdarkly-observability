import Foundation

public enum CommonOTelPath {
    public static let logsPath = "/v1/logs"
    public static let metricsPath = "/v1/metrics"
    public static let tracesPath = "/v1/traces"
}

enum CommonOTelConfiguration {
    static let flushTimeout: TimeInterval = 5
}
