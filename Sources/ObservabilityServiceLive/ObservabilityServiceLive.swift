import Foundation
import OSLog

import ApplicationServices
import OTelInstrumentation
import iOSSessionService
import KSCrashReportService
import Sampling
import SamplingLive
import SystemMetricsLive
import Common

extension ObservabilityService {
    public static let noOp: Self = .init(
        metricsService: .noOp,
        tracesService: .noOp,
        logsService: .noOp,
        cpuUsageMeterService: .noOp
    )
    
    public static func build(
        mobileKey: String,
        options: Options
    ) throws -> Self {
        var options = options
        options.resourceAttributes = options.resourceAttributes
            .merging(ExtendedResourceAttributes.value) { current, _ in current }
        
        let sampler = ExportSampler.build(sampler: ThreadSafeSampler.shared.sample(_:))
        let sessionService = SessionService.build(options: options)
        let metricsService = try MetricsService.buildHttp(sessionService: sessionService, options: options)
        let tracesService = try TracesService.buildHttp(sessionService: sessionService, options: options, sampler: sampler)
        let logsService = try LogsService.buildHttp(sessionService: sessionService, options: options, sampler: sampler)
        let userInteractionService = UserInteractionService.build(tracesService: tracesService)
        userInteractionService.start()
        
        let cpuUsageMetrics = CpuUsageMeterService.build(
            monitoringInterval: 2,
            metricsService: metricsService,
            log: options.log
        )
        cpuUsageMetrics.startMonitoring()

        Task {
            do {
                guard let url = URL(string: options.backendUrl) else {
                    throw InstrumentationError.invalidGraphQLUrl
                }
                let graphQLClient = GraphQLClient(endpoint: url)
                let samplingConfigClient = DefaultSamplingConfigClient(client: graphQLClient)
                let config = try await samplingConfigClient.getSamplingConfig(mobileKey: mobileKey)
                sampler.setConfig(config)
            } catch {
                os_log("%{public}@", log: options.log, type: .error, "getSamplingConfig failed with error: \(error)")
            }
        }
        
        do {
            let crashReportService = try CrashReportService.build(logsService: logsService, options: options)
            crashReportService.logPendingCrashReports()
        } catch {
            os_log("%{public}@", log: options.log, type: .error, "Crash report service initialization failed with error: \(error)")
        }
            
        
        return .init(
            metricsService: metricsService,
            tracesService: tracesService,
            logsService: logsService,
            cpuUsageMeterService: cpuUsageMetrics
        )
    }
}
