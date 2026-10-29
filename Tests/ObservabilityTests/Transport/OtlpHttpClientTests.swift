import Foundation
import Testing
@testable import LaunchDarklyOtel

struct OtlpHttpClientTests {
    private let endpoint = URL(string: "https://otel.example.com/v1/traces")!

    @Test("Custom headers from the configuration are added to OTLP requests")
    func appliesConfigHeaders() throws {
        let client = OtlpHttpClient(
            endpoint: endpoint,
            config: OtlpConfiguration(headers: [("X-Custom-Header", "custom-value"), ("Authorization", "Bearer token")]),
            envVarHeaders: nil
        )

        let request = try client.createRequest(jsonBody: ["key": "value"])

        #expect(request.value(forHTTPHeaderField: "X-Custom-Header") == "custom-value")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("OTel-OTLP-Exporter-Swift/") == true)
    }

    @Test("Custom headers override built-in and environment headers")
    func configHeadersTakePrecedence() throws {
        let client = OtlpHttpClient(
            endpoint: endpoint,
            config: OtlpConfiguration(headers: [("User-Agent", "custom-agent"), ("X-Shared", "from-config")]),
            envVarHeaders: [("X-Shared", "from-env"), ("X-Env-Only", "env-value")]
        )

        let request = try client.createRequest(jsonBody: ["key": "value"])

        #expect(request.value(forHTTPHeaderField: "User-Agent") == "custom-agent")
        #expect(request.value(forHTTPHeaderField: "X-Shared") == "from-config")
        #expect(request.value(forHTTPHeaderField: "X-Env-Only") == "env-value")
    }
}
