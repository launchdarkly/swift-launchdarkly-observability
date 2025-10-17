import Testing
@testable import Observability

final class UIEventReceiverCheckerTests {
    // MARK: - Doubles
    final class UIRemoteKeyboardWindowFake {}
    final class UITextEffectsWindowShadow {}
    final class RegularReceiver {}
    final class FooViewReceiver {}
    final class BazReceiver {}

    @Test("Default ignore list: keyboard and text effects windows are not tracked")
    func defaultIgnores() {
        let checker = UIEventReceiverChecker()

        let keyboardWindow = UIRemoteKeyboardWindowFake()
        let textEffectsWindow = UITextEffectsWindowShadow()

        #expect(checker.shouldTrack(keyboardWindow) == false)
        #expect(checker.shouldTrack(textEffectsWindow) == false)
    }

    @Test("Default behavior: arbitrary receivers are tracked")
    func tracksOtherReceivers() {
        let checker = UIEventReceiverChecker()
        let receiver = RegularReceiver()

        #expect(checker.shouldTrack(receiver) == true)
    }

    @Test("Custom ignore list is respected")
    func customIgnoreList() {
        let checker = UIEventReceiverChecker(ignoreClasses: ["Foo", "Bar"]) 

        let fooReceiver = FooViewReceiver()
        let bazReceiver = BazReceiver()

        #expect(checker.shouldTrack(fooReceiver) == false)
        #expect(checker.shouldTrack(bazReceiver) == true)
    }

    @Test("Results are cached per instance via ObjectIdentifier")
    func cachesPerInstance() {
        let checker = UIEventReceiverChecker()
        let receiver = RegularReceiver()

        #expect(checker.tracked.isEmpty)

        let first = checker.shouldTrack(receiver)
        #expect(checker.tracked.count == 1)
        #expect(checker.tracked[ObjectIdentifier(receiver)] == first)

        let second = checker.shouldTrack(receiver)
        #expect(second == first)
        #expect(checker.tracked.count == 1) // no new entries addeds
    }

    @Test("Different instances of the same class use distinct cache keys")
    func distinctInstancesHaveDistinctCacheEntries() {
        let checker = UIEventReceiverChecker()
        let a = RegularReceiver()
        let b = RegularReceiver()

        #expect(checker.tracked.isEmpty)
        #expect(checker.shouldTrack(a) == true)
        #expect(checker.shouldTrack(b) == true)

        #expect(checker.tracked.count == 2)
        #expect(ObjectIdentifier(a) != ObjectIdentifier(b))
    }
}


