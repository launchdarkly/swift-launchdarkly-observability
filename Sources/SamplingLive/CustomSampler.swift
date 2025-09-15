import Foundation

import OpenTelemetryApi
import OpenTelemetrySdk

import Common
import Sampling

extension ExportSampler {
    public static func customSampler(
        sampler: ((Int) -> Bool)? = nil
    ) -> Self {
        final class CustomSampler {
            private let sampler: (Int) -> Bool
            private let queue = DispatchQueue(label: "com.launchdarkly.sampler.custom", attributes: .concurrent)
            private var _config: SamplingConfig?
            private var config: SamplingConfig? {
                get {
                    queue.sync { [weak self] in self?._config }
                }
                set {
                    queue.async(flags: .barrier) { [weak self] in self?._config = newValue }
                }
            }
            
            init(config: SamplingConfig? = nil, sampler: ((Int) -> Bool)? = nil) {
                self._config = config
                self.sampler = sampler ?? ThreadSafeSampler.shared.sample(_:)
            }
            
            func sampleSpan(_ spanData: SpanData) -> SamplingResult {
                guard let config else {
                    return .init(sample: true)
                }
                
                for spanConfig in config.spans ?? [] {
                    if matchesSpanConfig(config: spanConfig, span: spanData) {
                        return .init(
                            sample: sampler(spanConfig.samplingRatio),
                            attributes: [LDSemanticAttribute.ATTR_SAMPLING_RATIO: .int(spanConfig.samplingRatio)]
                        )
                    }
                }
                
                /// Didn't match any sampling config, or there were no configs, so we sample it.
                return .init(sample: true)
            }
            
            func sampleLog(_ logData: ReadableLogRecord) -> SamplingResult {
                guard let config, !(config.logs?.isEmpty ?? true) else {
                    return .init(sample: true)
                }
                
                for logConfig in config.logs ?? [] {
                    if matchesLogConfig(config: logConfig, record: logData) {
                        return .init(
                            sample: sampler(logConfig.samplingRatio),
                            attributes: [LDSemanticAttribute.ATTR_SAMPLING_RATIO: .int(logConfig.samplingRatio)]
                        )
                    }
                }
                
                /// Didn't match any sampling config, or there were no configs, so we sample it.
                return .init(sample: true)
            }
            
            func setConfig(_ config: SamplingConfig?) {
                self.config = config
            }
            
            /// Check if sampling is enabled.
            /// Sampling is enabled if there is at least one configuration in either the log or span sampling.
            /// - Returns: true if sampling is enabled
            func isSamplingEnabled() -> Bool {
                guard let config else {
                    return false
                }
                
                return config.spans?.isEmpty == false || config.logs?.isEmpty == false
            }
            
            private func matchesValue(
                matchConfig: MatchConfig?,
                value: AttributeValue
            ) -> Bool {
                guard let matchConfig else { return false }
                switch matchConfig {
                case .basic(let configValue):
                    return configValue == value
                case .regex(let pattern):
                    guard case .string(let valueString) = value else { return false }
                    return valueString.matches(pattern)
                }
            }
            
            private func matchesAttributes(
                attributeConfigs: [AttributeMatchConfig]?,
                attributes: [String: AttributeValue]?
            ) -> Bool {
                guard let attributeConfigs else {
                    return true
                }
                guard !attributeConfigs.isEmpty else {
                    return true
                }
                
                // No attributes, so they cannot match.
                guard let attributes else {
                    return false
                }
                
                return attributeConfigs.allSatisfy { config in
                    let result = attributes.contains { key, value in
                        let match = matchesValue(matchConfig: config.key, value: .string(key)) && matchesValue(matchConfig: config.attribute, value: value)
                        return match
                    }
                    return result
                }
            }
            
            private func matchEvent(
                eventConfig: SpanEventMatchConfig,
                event: SpanData.Event
            ) -> Bool {
                if let eventConfigName = eventConfig.name {
                    // Match by Event name
                    if !matchesValue(matchConfig: eventConfigName, value: .string(event.name)) {
                        return false
                    }
                }
                
                // Match by event attributes if specified
                if !matchesAttributes(attributeConfigs: eventConfig.attributes, attributes: event.attributes) {
                    return false
                }
                
                return true
            }
            
            private func matchesEvents(
                eventConfigs: [SpanEventMatchConfig]?,
                events: [SpanData.Event]
            ) -> Bool {
                guard let eventConfigs else {
                    return true
                }
                
                guard !eventConfigs.isEmpty else {
                    return true
                }
                
                guard !events.isEmpty else {
                    return false
                }
                
                
                return eventConfigs.allSatisfy { eventConfig in
                    events.contains { event in
                        matchEvent(eventConfig: eventConfig, event: event)
                    }
                }
            }
            
            private func matchesSpanConfig(
                config: SpanSamplingConfig,
                span: SpanData
            ) -> Bool {
                // Check span name if it's defined in the config
                if let configName = config.name {
                    if !matchesValue(matchConfig: configName, value: .string(span.name)) {
                        return false
                    }
                }
                
                if !matchesAttributes(attributeConfigs: config.attributes, attributes: span.attributes) {
                    return false
                }
                
                return matchesEvents(eventConfigs: config.events, events: span.events)
            }
            
            private func matchesLogConfig(
                config: LogSamplingConfig,
                record: ReadableLogRecord
            ) -> Bool {
                if let severityText = config.severityText, let severity = record.severity?.description {
                    if !matchesValue(matchConfig: severityText, value: .string(severity)) {
                        return false
                    }
                }
                if let configName = config.message, let body = record.body {
                    if !matchesValue(matchConfig: configName, value: body) {
                        return false
                    }
                }
                
                return matchesAttributes(attributeConfigs: config.attributes, attributes: record.attributes)
            }
            
        }
        
        let sampler = CustomSampler(sampler: sampler)
    
        return .init(
            sampleSpan: { sampler.sampleSpan($0) },
            sampleLog: { sampler.sampleLog($0) },
            isSamplingEnabled: { sampler.isSamplingEnabled() },
            setConfig: { sampler.setConfig($0) }
        )
    }
}
