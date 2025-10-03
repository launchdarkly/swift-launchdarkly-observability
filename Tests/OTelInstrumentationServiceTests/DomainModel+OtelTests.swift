import Testing
import OpenTelemetryApi

import DomainModels
import OTelInstrumentationService

struct DomainModelOtelTests {
    @Test
    func domainAttributeValueToOTelAttributeValueTransformation() {
        let string = "Hello, World!"
        let domainAttribute = DomainModels.AttributeValue.string(string)
        let oTelAttributeValue = domainAttribute.toOTel()
     
        #expect(oTelAttributeValue.description == string)
        
        let array = ["a", "b", "c"]
        let domainAttributeArray = array.map { DomainModels.AttributeValue.string($0) }
        let domainArray = DomainModels.AttributeValue.array(domainAttributeArray)
        let otelArray = domainArray.toOTel()
        
        if case .array(let values) = otelArray {
            for index in values.values.indices {
                #expect(values.values[index].description == array[index])
            }
        } else {
            #expect(array.isEmpty) /// this always will fail, XCTFail() workaround
        }
    }
    
    @Test
    func domainSeverityToOTelSeverityTransformation() {
        let domainSeverity: DomainModels.Severity = .info
        let otelSeverity = domainSeverity.toOtel()
        #expect(otelSeverity == .info)
    }
}
