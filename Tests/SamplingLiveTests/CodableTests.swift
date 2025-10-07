import Foundation
import Testing

import Sampling

struct ConfigCodableTests {
    @Test
    func matchConfig() throws {
        let config = MatchConfig.basic(value: .string("Hello, World!"))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(config)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print("Could not convert Data to String.")
            }
        } catch let error {
            print("Error encoding user: \(error)")
        }
    }
}
