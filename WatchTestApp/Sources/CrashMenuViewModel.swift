import Darwin
import Foundation
import LaunchDarkly

/// The watch counterpart of the three kill/crash scenarios in the iOS test app's `MainMenuViewModel`.
///
/// Each one records the same pair -- an evaluation (the exposure) and a track standing in for an error -- and then ends
/// the process a different way. What differs between them is how much opportunity the SDK gets to deliver the pair
/// before it dies, so together they separate "delivered in time" from "was already on disk".
final class CrashMenuViewModel: ObservableObject {
	private let flagKey = "kill-flag"
	private let trackKey = "$ld:telemetry:error"

	/// Flushes and waits, so the events should arrive on this launch.
	///
	/// This is the control: the SDK is given an explicit flush and five seconds of runway before `SIGKILL`. Nothing
	/// arriving here means something is wrong beyond persistence.
	func evalTrackFlushThenKill() {
		let client = LDClient.get()
		_ = client?.boolVariation(forKey: flagKey, defaultValue: false)
		client?.track(key: trackKey)
		client?.flush()
		DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
			kill(getpid(), SIGKILL)
		}
	}

	/// Nothing at all between the track and the process dying: no flush, no delay for a timer to fire in, and `SIGKILL`,
	/// which cannot be caught, so no part of the SDK runs on the way out.
	///
	/// Whether the exposure and the track are reported therefore says exactly one thing: whether recording them had
	/// already put them on disk. They should arrive on the next launch of the app, not this one.
	func evalTrackThenKillNow() {
		let client = LDClient.get()
		_ = client?.boolVariation(forKey: flagKey, defaultValue: false)
		client?.track(key: trackKey)
		kill(getpid(), SIGKILL)
	}

	/// The same again, ending in a Swift runtime trap instead of a signal the process never sees.
	///
	/// This is the shape the customer report takes: app code hits a fatal error immediately after reporting it.
	func evalTrackThenFatalErrorNow() {
		let client = LDClient.get()
		_ = client?.boolVariation(forKey: flagKey, defaultValue: false)
		client?.track(key: trackKey)
		fatalError("Eval+Fatal: deliberate fatalError immediately after track, to test event persistence")
	}
}
