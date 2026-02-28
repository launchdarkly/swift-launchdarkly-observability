import Foundation
import SwiftProtobuf
import LaunchDarkly
#if !LD_COCOAPODS
    import OpenTelemetryProtocolExporterCommon
    import Common
#endif

public final class OtlpHttpClient {
    public enum Constants {
      public enum OTLP {
        public static let version = "0.20.0"
      }

      public enum HTTP {
        public static let userAgent = "User-Agent"
      }
    }
    private enum Headers {
      // GetUserAgentHeader returns an OTLP header value of the form "OTel OTLP Exporter Swift/{{ .Version }}"
      // https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/protocol/exporter.md#user-agent
      public static func getUserAgentHeader() -> String {
        var version = Constants.OTLP.version
        if !version.isEmpty, version.hasPrefix("v") {
          version = String(version.dropFirst(1))
        }
        let userAgent = "OTel-OTLP-Exporter-Swift/\(version)"

        return userAgent
      }
    }

    let endpoint: URL
    let httpService: HttpServicing
    let envVarHeaders: [(String, String)]?
    let config: OtlpConfiguration
    
    public init(endpoint: URL,
                config: OtlpConfiguration = OtlpConfiguration(),
                useSession: URLSession? = nil,
                envVarHeaders: [(String, String)]? = EnvVarHeaders.attributes) {
        self.envVarHeaders = envVarHeaders
        self.endpoint = endpoint
        self.config = config
        if let useSession {
            httpService = HttpService(session: useSession)
        } else {
            httpService = HttpService()
        }
    }
    
    func createRequest(body: Message, explicitTimeout: TimeInterval? = nil) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        if let headers = envVarHeaders {
            headers.forEach { key, value in
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        request.timeoutInterval = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, config.timeout)

        do {
            let rawData = try body.serializedData()
            request.httpMethod = "POST"
            request.setValue(Headers.getUserAgentHeader(), forHTTPHeaderField: Constants.HTTP.userAgent)
            request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
            if let compressedData = rawData.ld_gzip() {
                request.httpBody = compressedData
                request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
            } else {
                request.httpBody = rawData
            }
        } catch {
            throw NetworkError.invalidRequest(cause: error)
        }
        
        return request
    }
    
    public func send(body: Message, explicitTimeout: TimeInterval? = nil) async throws  {
        let request = try createRequest(body: body, explicitTimeout: explicitTimeout)
        try await httpService.send(request)
    }

}
