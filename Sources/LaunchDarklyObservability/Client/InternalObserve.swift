protocol InternalObserve: Observe {
    var logClient: LogsApi { get }
    var traceClient: TracesApi { get }
}
