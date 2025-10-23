import Foundation
import URLSessionInstrumentation

final class NetworkInstrumentationManager: AutoInstrumentation {
    private let uRLSessionInstrumentation: URLSessionInstrumentation
    
    func start() {}
    func stop() {}
    
    init(options: Options, tracer: Tracer, session: SessionManaging) {
        let defaults = ConfigurationDefaults(options: options, session: session)
        let configuration = URLSessionInstrumentationConfiguration(
            shouldInstrument: defaults.shouldInstrument(urlRequest:),
            nameSpan: defaults.nameSpan(urlRequest:),
            spanCustomization: defaults.spanCustomization(urlRequest:spanBuilder:),
            shouldInjectTracingHeaders: defaults.shouldInjectTracingHeaders(urlRequest:),
            injectCustomHeaders: defaults.injectCustomHeaders(urlRequest:span:),
            tracer: tracer
        )
        self.uRLSessionInstrumentation = .init(configuration: configuration)
    }
}

fileprivate struct ConfigurationDefaults {
    private let options: Options
    private let session: SessionManaging
    
    init(options: Options,  session: SessionManaging) {
        self.options = options
        self.session = session
    }
    
    func shouldInstrument(urlRequest: URLRequest) -> Bool? {
        guard let urlString = urlRequest.url?.absoluteString.lowercased() else {
            return false
        }
        let otlpEndpoint = options.otlpEndpoint.lowercased()
        let backendUrl = options.backendUrl
        let isNotOtelEndpoint = urlString.contains(otlpEndpoint) == false
        let isNotMobileLaunchDarklyUrl = urlString.contains("https://mobile.launchdarkly.com/mobile") == false
        let isNotBackendUrl = urlString.contains(backendUrl) == false
        let isNotInUrlBlocklist = {
            return options.urlBlocklist.contains { url in
                return urlString.contains(url.lowercased())
            }
        }() == false
        
        return isNotOtelEndpoint && isNotMobileLaunchDarklyUrl && isNotBackendUrl && isNotInUrlBlocklist
    }
    
    func nameSpan(urlRequest: URLRequest) -> String? {
        "http.request"
    }
    
    func spanCustomization(urlRequest: URLRequest, spanBuilder: any SpanBuilder) {
        if let httpMethod = urlRequest.httpMethod {
            spanBuilder.setAttribute(key: "http.method", value: httpMethod)
        }
        if let url = urlRequest.url {
            spanBuilder.setAttribute(key: "http.url", value: url.absoluteString)
        }
        
        let sessionId = session.sessionInfo.id
        if !sessionId.isEmpty {
            spanBuilder.setAttribute(key: SemanticConvention.highlightSessionId, value: sessionId)
        }
    }
    
    func shouldInjectTracingHeaders(urlRequest: URLRequest) -> Bool? {
        guard let url = urlRequest.url?.absoluteString.lowercased() else {
            return false
        }
        let contains = options.urlBlocklist.contains { blockedUrl in
            return url.contains(blockedUrl.lowercased())
        }
        guard !contains else {
            return false
        }
        
        switch options.tracingOrigins {
        case .enabled(let list):
            return list.contains { origin in
                url.contains(origin.lowercased())
            }
        case .enabledRegex(let regex):
            let patterns = regex + ["localhost", "^/"]
            
            return patterns.contains { regex in
                url.matches(regex)
            }
        case .disabled:
            return true
        }
    }
    
    func injectCustomHeaders(urlRequest: inout URLRequest, span: (any OpenTelemetryApi.Span)?) {
        guard let span else { return }
        var carrier = [String: String]()
        OpenTelemetry.instance.propagators.textMapPropagator.inject(
            spanContext: span.context,
            carrier: &carrier,
            setter: setter
        )
        carrier.forEach { (key: String, value: String) in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
    }
}

fileprivate let setter = W3CTraceContextSetter()
fileprivate struct W3CTraceContextSetter: Setter {
    func set(carrier: inout [String : String], key: String, value: String) {
        carrier[key] = value
    }
}
