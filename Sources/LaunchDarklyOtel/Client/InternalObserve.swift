protocol InternalObserve: Observe {
    var logClient: LogRecording { get }
    var traceClient: TracesApi { get }
}
