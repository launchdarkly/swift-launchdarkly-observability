import Foundation
import Testing
import Shared

@Test func generateUniqueIdTests() throws {
    let uuid = generateUniqueId()
    print("uuid: \(uuid)")
    print("uuid: \(UUID().uuidString)")
}
