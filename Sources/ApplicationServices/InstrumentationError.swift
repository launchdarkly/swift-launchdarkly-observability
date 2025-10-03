public enum InstrumentationError: Error {
    case traceExporterUrlIsInvalid
    case logExporterUrlIsInvalid
    case metricExporterUrlIsInvalid
    case graphQLUrlIsInvalid
}
