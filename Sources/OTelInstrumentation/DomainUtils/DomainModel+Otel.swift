import OpenTelemetryApi
import ResourceExtension

import DomainModels
//DefaultResources().get()



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

extension OpenTelemetryApi.AttributeValue {
    public func toODomain() -> DomainModels.AttributeValue {
        switch self {
        case .string(let string):
            return .string(string)
        case .bool(let bool):
            return .bool(bool)
        case .int(let int):
            return .int(int)
        case .double(let double):
            return .double(double)
        case .stringArray(let array):
            return .array(array.map { .string($0) })
        case .boolArray(let array):
            return .array(array.map { .bool($0) })
        case .intArray(let array):
            return .array(array.map { .int($0) })
        case .doubleArray(let array):
            return .array(array.map { .double($0) })
        case .array(let attributeArray):
            return .array(attributeArray.values.map { $0.toODomain() })
        case .set(let attributeSet):
            return .set(attributeSet.labels.mapValues { $0.toODomain() })
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

public struct ExtendedResourceAttributes {
    public static let value = DefaultResources().get().attributes.mapValues { $0.toODomain() }
}
