import LaunchDarkly
import SwiftUI

@main
struct WatchTestAppApp: App {
	init() {
		LaunchDarklyBootstrap.start()
	}

	var body: some Scene {
		WindowGroup {
			CrashMenuView()
		}
	}
}

/// Starts the flag SDK on its own.
///
/// The iOS test app installs `Observability` as an `LDConfig` plugin, but that package builds for iOS and tvOS only, so
/// the watch app runs the flag SDK bare. That suits what this app is for: the questions here are about whether the SDK
/// puts an exposure and a track on disk before the process dies, which the plugin plays no part in.
enum LaunchDarklyBootstrap {
	static func start() {
		guard let mobileKey = Bundle.main.infoDictionary?["mobileKey"] as? String, !mobileKey.isEmpty else {
			fatalError("Missing mobileKey in Info.plist. See TestAppShared/Secrets.xcconfig.example.")
		}

		var config = LDConfig(mobileKey: mobileKey, autoEnvAttributes: .enabled)
		config.eventPersistence = .immediate

		let context = { () -> LDContext in
			var contextBuilder = LDContextBuilder(key: "12345")
			contextBuilder.kind("user")
			do {
				return try contextBuilder.build().get()
			} catch {
				abort()
			}
		}()

		LDClient.start(config: config, context: context, startWaitSeconds: 5.0)
	}
}
