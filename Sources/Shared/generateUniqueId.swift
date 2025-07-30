public func generateUniqueId() -> String {
    do {
        let timestamp = try Date().timeIntervalSince1970.description.toHexString()
        let random1 = try Double.random(in: 0.0..<1.0).description.toHexString().substring(offset: 2, length: 10)
        let random2 = try Double.random(in: 0.0..<1.0).description.toHexString().substring(offset: 2, length: 6)
        let random3 = try Double.random(in: 0.0..<1.0).description.toHexString().substring(offset: 2, length: 6)
        let random4 = try Double.random(in: 0.0..<1.0).description.toHexString().substring(offset: 2, length: 14)
        
        let pad: (String, Int) throws -> String = { str, length in
            str.padEnd(toLength: length, withPad: "0").substring(offset: 0, length: UInt(length))
        }
        
        let p1 = try pad(timestamp.substring(offset: 0, length: 8), 8)
        let p2 = try pad(random1.substring(offset: 0, length: 8), 8)
        let p3 = "4" + (try pad(random2.substring(offset: 0, length: 3), 3))
        let p4 = ["8", "9", "a", "b"][Int(floor(Double.random(in: 0.0..<1.0) * 4))] + (try pad(random3.substring(offset: 0, length: 3), 3))
        let p5 = try pad(random4, 12)
        
        return [
            p1,
            p2,
            p3,
            p4,
            p5
        ].joined(separator: "-")
    } catch {
        return UUID().uuidString
    }
}

// TODO: Generate Unique ID for session ID
/*
 /**
  * Simple unique ID generator for React Native
  * Generates IDs that are unique enough for session/device tracking
  * without requiring crypto or uuid dependencies
  */

 /**
  * Generates a unique ID similar to UUID format but using simple randomization
  * Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx (where x is random hex, y is 8,9,a,b)
  */
 export function generateUniqueId(): string {
     const timestamp = Date.now().toString(16) // Convert to hex
     const random1 = Math.random().toString(16).substring(2, 10) // 8 chars
     const random2 = Math.random().toString(16).substring(2, 6) // 4 chars
     const random3 = Math.random().toString(16).substring(2, 6) // 4 chars
     const random4 = Math.random().toString(16).substring(2, 14) // 12 chars

     // Ensure we have enough padding
     const pad = (str: string, length: number) =>
         str.padEnd(length, '0').substring(0, length)

     return [
         pad(timestamp.substring(0, 8), 8),
         pad(random1.substring(0, 4), 4),
         '4' + pad(random2.substring(0, 3), 3), // Version 4 UUID format
         ['8', '9', 'a', 'b'][Math.floor(Math.random() * 4)] +
             pad(random3.substring(0, 3), 3),
         pad(random4, 12),
     ].join('-')
 }

 /**
  * Generates a shorter unique ID for cases where full UUID length isn't needed
  */
 export function generateShortId(): string {
     const timestamp = Date.now().toString(36) // Base36 for shorter string
     const random = Math.random().toString(36).substring(2, 8)
     return `${timestamp}_${random}`
 }
 */
