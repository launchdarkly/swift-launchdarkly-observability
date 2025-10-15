import OpenTelemetryApi
import OpenTelemetrySdk
import Common

/** Shared info between plugins */
public struct ObservabilityContext {
    public let sdkKey: String
    public let options: Options
    public var sessionManager: SessionManaging
    public var transportService: TransportServicing

    public init(
        sdkKey: String,
        options: Options,
        sessionManager: SessionManaging,
        transportService: TransportServicing) {
        self.sdkKey = sdkKey
        self.options = options
        self.sessionManager = sessionManager
        self.transportService = transportService
    }
}
