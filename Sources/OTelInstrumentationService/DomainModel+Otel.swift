import OpenTelemetryApi

import DomainModels

extension DomainModels.AttributeValue {
    public func toOTel() -> OpenTelemetryApi.AttributeValue {
        switch self {
        case .string(let string):
            return OpenTelemetryApi.AttributeValue.string(string)
        case .bool(let bool):
            return OpenTelemetryApi.AttributeValue.bool(bool)
        case .int(let int):
            return OpenTelemetryApi.AttributeValue.int(int)
        case .double(let double):
            return OpenTelemetryApi.AttributeValue.double(double)
        case .array(let attributeArray):
            return OpenTelemetryApi.AttributeValue.array(
                .init(
                    values: attributeArray.map({ $0.toOTel() })
                )
            )
        case .set(let dictionary):
            let labels = dictionary.mapValues { $0.toOTel() }
            return OpenTelemetryApi.AttributeValue.set(
                .init(
                    labels: labels
                )
            )
        }
    }
}

extension DomainModels.Severity {
    private static let allCases = DomainModels.Severity.allCases.compactMap { OpenTelemetryApi.Severity(rawValue: $0.rawValue) }
    public func toOtel() -> OpenTelemetryApi.Severity {
        /// Severity is 1-based index
        return DomainModels.Severity.allCases[self.rawValue - 1]
    }
}
