import Testing
import OpenTelemetryApi
import Observability
//import LaunchDarklyObservability

struct DomainModelOtelTests {
    @Test
    func domainAttributeValueToOTelAttributeValueTransformation() {
        let string = "Hello, World!"
        let domainAttribute = Observability.AttributeValue.string(string)
        let oTelAttributeValue = domainAttribute.toOTel()
     
        #expect(oTelAttributeValue.description == string)
        
        let array = ["a", "b", "c"]
        let domainAttributeArray = array.map { Observability.AttributeValue.string($0) }
        let domainArray = Observability.AttributeValue.array(domainAttributeArray)
        let otelArray = domainArray.toOTel()
        
        if case .array(let values) = otelArray {
            for index in values.values.indices {
                #expect(values.values[index].description == array[index])
            }
        } else {
            Issue.record("Expected to get an .array value from the OTEL AttributeValue, but got something else")
        }
    }
    
    @Test
    func domainSeverityToOTelSeverityTransformation() {
        var domainSeverity: Observability.Severity = .info
        var otelSeverity = domainSeverity.toOtel()
        #expect(otelSeverity == .info)
        
        domainSeverity = .info4
        otelSeverity = domainSeverity.toOtel()
        #expect(otelSeverity == .info4)
    }
}
