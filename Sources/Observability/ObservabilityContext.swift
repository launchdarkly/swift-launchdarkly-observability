import OpenTelemetryApi
import OpenTelemetrySdk
import Common

/** Shared info between plugins */
public struct ObservabilityContext {
    public let sdkKey: String
    public let options: Options
    public var sessionService: SessionService
    public var transportService: TransportServicing

    public init(
        sdkKey: String,
        options: Options,
        sessionService: SessionService,
        transportService: TransportServicing) {
        self.sdkKey = sdkKey
        self.options = options
        self.sessionService = sessionService
        self.transportService = transportService
    }
}
