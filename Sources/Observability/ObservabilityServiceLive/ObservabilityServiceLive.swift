import Foundation
import OSLog
import Common

extension ObservabilityService {
    public static let noOp: Self = .init(
        metricsService: .noOp,
        tracesService: .noOp,
        logsService: .noOp
    )
    
    public static func build(
        mobileKey: String,
        options: Options
    ) throws -> Self {
        var options = options
        options.resourceAttributes = options.resourceAttributes
            .merging(ExtendedResourceAttributes.value) { current, _ in current }
     
        guard let url = URL(string: options.backendUrl) else {
            throw InstrumentationError.invalidGraphQLUrl
        }
        let graphQLClient = GraphQLClient(endpoint: url)
       
        let eventQueue = EventQueue()
        let sampler = ExportSampler.build(sampler: ThreadSafeSampler.shared.sample(_:))
        let sessionService = SessionService.build(options: options)
        let metricsService = try MetricsService.buildHttp(sessionService: sessionService, options: options)
        let tracesService = try TracesService.buildHttp(sessionService: sessionService, options: options, sampler: sampler)
        let logsService = try LogsService.buildHttp(sessionService: sessionService, options: options, sampler: sampler, eventQueue: eventQueue)
    
        let userInteractionService = UserInteractionService.build(tracesService: tracesService, eventQueue: eventQueue)
        userInteractionService.start()
        
        Task {
            do {
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
                 
        let batchWorker = BatchWorker(eventQueue: eventQueue)
        guard let url = URL(string: options.otlpEndpoint)?.appendingPathComponent(CommonOTelPath.logsPath) else {
            throw InstrumentationError.invalidLogExporterUrl
        }
        
        let logExporter = ObservabilityExporter(endpoint: url)
        Task {
            await batchWorker.addExporter(logExporter)
        }
       
        let transportService = TransportService(eventQueue: eventQueue, batchWorker: batchWorker, sessionService: sessionService)
        let context = ObservabilityContext(sdkKey: mobileKey,
                                           options: options,
                                           sessionService: sessionService,
                                           transportService: transportService)
        transportService.start()
        
        return .init(
            context: context,
            metricsService: metricsService,
            tracesService: tracesService,
            logsService: logsService
        )
    }
}
