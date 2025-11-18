import Testing
@testable import LaunchDarklyObservability

struct AppLogsClientTests {
    @Test("Logs disabled")
    func logsDisabled() {
        let spy = LogsApiSpy()
        
        let sut = AppLogClient(
            logLevel: .none,
            logger: spy
        )
        
        for level in OTelSeverities {
            sut.recordLog(message: "message", severity: level, attributes: [:])
        }
        
        #expect(spy.invokeCount == 0)
    }
    
    @Test("Logs enabled")
    func theSameLevelEnabled() {
        let spy = LogsApiSpy()

        for severity in OTelSeverities {
            guard let level = Options.LogLevel(rawValue: severity.rawValue) else {
                continue
            }
            let sut = AppLogClient(
                logLevel: level,
                logger: spy
            )
            sut.recordLog(message: "message", severity: severity, attributes: [:])
            #expect(spy.invokeCountByLevel[level] == 1)
        }
    }
    
    @Test("Logs level")
    func logsLevel() {
        var spy = LogsApiSpy()

        
        var sut = AppLogClient(
            logLevel: .error4,
            logger: spy
        )
        
        for severity in OTelSeverities {
            sut.recordLog(message: "message", severity: severity, attributes: [:])
        }
        
        var allowedLogLevels = [
            OpenTelemetryApi.Severity.error4,
                .fatal,
                .fatal2,
                .fatal3,
                .fatal4
        ]
        
        #expect(spy.invokeCount == allowedLogLevels.count)
        
        
        spy = LogsApiSpy()
        sut = AppLogClient(
            logLevel: .debug,
            logger: spy
        )
        
        for severity in OTelSeverities {
            sut.recordLog(message: "message", severity: severity, attributes: [:])
        }
        
        
        allowedLogLevels = [
            OpenTelemetryApi.Severity.debug,
            .debug2,
            .debug3,
            .debug4,
            .info,
            .info2,
            .info3,
            .info4,
            .warn,
            .warn2,
            .warn3,
            .warn4,
            .error,
            .error2,
            .error3,
            .error4,
            .fatal,
            .fatal2,
            .fatal3,
            .fatal4
        ]
        #expect(spy.invokeCount == allowedLogLevels.count)
    }
}

fileprivate let OTelSeverities = [
    OpenTelemetryApi.Severity.trace,
    .trace2,
    .trace3,
    .trace4,
    .debug,
    .debug2,
    .debug3,
    .debug4,
    .info,
    .info2,
    .info3,
    .info4,
    .warn,
    .warn2,
    .warn3,
    .warn4,
    .error,
    .error2,
    .error3,
    .error4,
    .fatal,
    .fatal2,
    .fatal3,
    .fatal4
]
final class LogsApiSpy: LogsApi {
    var invokeCount = 0
    var invokeCountByLevel = Options.LogLevel.allCases.reduce([Options.LogLevel: Int]()) { table, level in
        guard level != .none else { return table }
        var table = table
        table[level] = 0
        return table
    }
    func recordLog(message: String, severity: OpenTelemetryApi.Severity, attributes: [String : OpenTelemetryApi.AttributeValue]) {
        invokeCount += 1
        guard let level = Options.LogLevel(rawValue: severity.rawValue) else { return }
        invokeCountByLevel[level]? += 1
    }
}
