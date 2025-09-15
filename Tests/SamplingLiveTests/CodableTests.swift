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
    
    @Test
    func decodeConfig() throws {
        let jsonDecoder = JSONDecoder()
        guard let url = Bundle.module.url(forResource: "Config", withExtension: "json") else {
            print("Error: Could not find my_data.txt in bundle.")
            throw URLError(.fileDoesNotExist)
        }
        
        let data = try Data(contentsOf: url)
        do {
            _ = try jsonDecoder.decode(Root.self, from: data)
        } catch let error {
            throw error
        }
    }
}
