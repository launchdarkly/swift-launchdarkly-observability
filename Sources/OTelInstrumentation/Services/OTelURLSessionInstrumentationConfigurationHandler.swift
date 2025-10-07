import Foundation

import OpenTelemetrySdk
import OpenTelemetryApi
import OpenTelemetryProtocolExporterHttp
import URLSessionInstrumentation

import ApplicationServices

extension URLSessionInstrumentationConfiguration {
    static func contextPropagationConfig(
        options: Options
    ) -> Self {
        let handler = OTelURLSessionInstrumentationConfigurationHandler(options: options)
        
        return .init(
            shouldInstrument: handler.shouldInstrument(urlRequest:),
            nameSpan: handler.nameSpan(urlRequest:),
            spanCustomization: handler.spanCustomization(urlRequest:spanBuilder:),
            shouldInjectTracingHeaders: handler.shouldInjectTracingHeaders(urlRequest:),
            injectCustomHeaders: handler.injectCustomHeaders(urlRequest:span:)
        )
    }
}

struct OTelURLSessionInstrumentationConfigurationHandler {
    private let options: Options
    
    init(options: Options) {
        self.options = options
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

private let setter = W3CTraceContextSetter()
struct W3CTraceContextSetter: Setter {
    func set(carrier: inout [String : String], key: String, value: String) {
        carrier[key] = value
    }
}
