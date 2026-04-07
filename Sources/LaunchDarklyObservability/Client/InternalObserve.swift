protocol InternalObserve: Observe {
    var logClient: InternalLogsApi { get }
    var traceClient: TracesApi { get }
}
