import UIKit.UIApplication
import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension
@_exported import Instrumentation

import Combine

public final class ObservabilityClient: @unchecked Sendable {
    private let tracerFacade: TracerFacade
    private let loggerFacade: LoggerFacade
    private let meterFacade: MeterFacade
    private var session: Session
    
    private var cachedSpans = [String: Span]()
    private var cancellables = Set<AnyCancellable>()
    
    private var onWillEndSession: @Sendable (_ sessionId: String) -> Void {
        { [weak self] sessionId in
            self?.willEndSession(sessionId)
        }
    }
    private var onDidStartSession: @Sendable (_ sessionId: String) -> Void {
        { [weak self] sessionId in
            self?.didStartSession(sessionId)
        }
    }
    
    public init(configuration: Configuration) {
        self.tracerFacade = TracerFacade(configuration: configuration)
        self.loggerFacade = LoggerFacade(configuration: configuration)
        self.meterFacade = MeterFacade(configuration: configuration)
        self.session = Session(options: SessionOptions(timeout: configuration.sessionTimeout))
        self.registerPropagators()

        
        self.session.start(
            onWillEndSession: onWillEndSession,
            onDidStartSession: onDidStartSession
        )
    }
    
    private func didStartSession(_ id: String) {
        let span = spanBuilder(spanName: "app.session.started")
            .setSpanKind(spanKind: .client)
            .startSpan()
        cachedSpans[id] = span
    }
    
    private func willEndSession(_ id: String) {
        guard let span = cachedSpans[id] else { return }
        span.end()
    }
    
    private func registerPropagators() {
        OpenTelemetry.registerPropagators(
            textPropagators: [
                W3CTraceContextPropagator(),
                B3Propagator(),
                JaegerPropagator(),
            ],
            baggagePropagator: W3CBaggagePropagator()
        )
    }
    
    // MARK: - Public API
    
    public static func defaultResource() -> Resource {
        DefaultResources().get()
    }
    
     public func spanBuilder(spanName: String) -> SpanBuilder {
        tracerFacade.spanBuilder(spanName: spanName)
    }
}
