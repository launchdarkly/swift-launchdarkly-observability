import Foundation
import Testing
import LaunchDarklyObservability

struct LaunchDarklyObservabilityTests {
    @Test func example() async throws {
        let key = "sdk-465cf811-71a3-42ee-8a9f-e325b6ed3a26"
        let client = DefaultObservabilityClient(
            sdkKey: key,
            resource: .init(),
            configuration: .init(
                customHeaders: [
                    ("X-LaunchDarkly-Project", "sdk-465cf811-71a3-42ee-8a9f-e325b6ed3a26")]
            )
        )
        await client.start()
        
        let span = await client.startSpan(name: "default observability client test")
        
        
        try await wait(for: 5.0)
        
        span.end()
        
        try await wait(for: 5.0)
    }
    
    func wait(for time: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(time))
    }
}
