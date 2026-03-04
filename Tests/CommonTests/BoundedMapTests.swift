import Testing
import Common

@Suite("BoundedMap")
struct BoundedMapTests {

    @Test("setValue stores value without eviction under capacity")
    func setWithoutEviction() {
        let map = BoundedMap<String, Int>(capacity: 2)
        let evicted = map.setValue(1, forKey: "a")

        #expect(evicted == nil)
        #expect(map.count == 1)
        #expect(map.removeValue(forKey: "a") == 1)
    }

    @Test("setValue evicts oldest when capacity exceeded")
    func fifoEviction() {
        let map = BoundedMap<String, Int>(capacity: 2)
        _ = map.setValue(1, forKey: "a")
        _ = map.setValue(2, forKey: "b")

        let evicted = map.setValue(3, forKey: "c")

        #expect(evicted?.key == "a")
        #expect(evicted?.value == 1)
        #expect(map.count == 2)
        #expect(map.removeValue(forKey: "a") == nil)
        #expect(map.removeValue(forKey: "b") == 2)
        #expect(map.removeValue(forKey: "c") == 3)
    }

    @Test("updating existing key refreshes insertion order")
    func updateExistingKeyRefreshesOrder() {
        let map = BoundedMap<String, Int>(capacity: 2)
        _ = map.setValue(1, forKey: "a")
        _ = map.setValue(2, forKey: "b")
        _ = map.setValue(10, forKey: "a") // "a" becomes newest

        let evicted = map.setValue(3, forKey: "c")

        #expect(evicted?.key == "b")
        #expect(evicted?.value == 2)
        #expect(map.removeValue(forKey: "a") == 10)
        #expect(map.removeValue(forKey: "b") == nil)
        #expect(map.removeValue(forKey: "c") == 3)
    }

    @Test("removeValue returns removed item and updates count")
    func removeValueBehavior() {
        let map = BoundedMap<String, Int>(capacity: 3)
        _ = map.setValue(1, forKey: "a")
        _ = map.setValue(2, forKey: "b")

        let removed = map.removeValue(forKey: "a")
        let missing = map.removeValue(forKey: "missing")

        #expect(removed == 1)
        #expect(missing == nil)
        #expect(map.count == 1)
    }

    @Test("capacity lower than 1 is clamped")
    func minimumCapacityClamp() {
        let map = BoundedMap<String, Int>(capacity: 0)
        _ = map.setValue(1, forKey: "a")
        let evicted = map.setValue(2, forKey: "b")

        #expect(evicted?.key == "a")
        #expect(evicted?.value == 1)
        #expect(map.count == 1)
        #expect(map.removeValue(forKey: "a") == nil)
        #expect(map.removeValue(forKey: "b") == 2)
    }
}
