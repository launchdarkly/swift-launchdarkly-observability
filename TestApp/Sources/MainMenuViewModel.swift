import Foundation
import LaunchDarkly
import LaunchDarklyObservability

final class MainMenuViewModel: ObservableObject {
	@Published var isNetworkInProgress: Bool = false
	private var screenViewCounter = 0
	
	func recordError() {
		LDObserve.shared.recordError(Failure.crash, attributes: [:])
	}
	
	func recordSpanAndVariation() {
		let span = LDObserve.shared.startSpan(
			name: "button-pressed",
			attributes: [:]
		)
		_ = LDClient.get()?.boolVariation(
			forKey: "feature1",
			defaultValue: false
		)
        
		span.end()
	}

	func triggerNestedSpans() {
		Task {
			let span0 = LDObserve.shared.startSpan(name: "NestedSpan", properties: ["test-true": true,
                                                                                    "test-double": 3.14])
			await OpenTelemetry.instance.contextProvider.withActiveSpan(span0) {
				let span1 = LDObserve.shared.startSpan(name: "NestedSpan1", attributes: [:])
				await OpenTelemetry.instance.contextProvider.withActiveSpan(span1) {
					let span2 = LDObserve.shared.startSpan(name: "NestedSpan2", attributes: [:])
					await OpenTelemetry.instance.contextProvider.withActiveSpan(span2) {
                        LDObserve.shared.recordCount(metric: .init(name: "NestedCounter", value: 10.0))
                        LDObserve.shared.recordLog(message: "NestedLog", severity: .info, attributes: [:])
						await Self.fetchURLsForNestedSpanDemo()
                        span2.end()
					}
					span1.end()
				}
				span0.end()
			}
		}
	}

	private static func fetchURLsForNestedSpanDemo() async {
		guard let google = URL(string: "https://www.google.com"),
		      let android = URL(string: "https://www.android.com/") else { return }
		_ = try? await URLSession.shared.data(from: google)
		_ = try? await URLSession.shared.data(from: android)
	}
	
	func recordMetric() {
		LDObserve.shared.recordMetric(
			metric: .init(name: "test-gauge", value: 50.0)
		)
	}

	func recordHistogramMetric() {
		LDObserve.shared.recordHistogram(
			metric: .init(name: "test-histogram", value: 15.0)
		)
	}

	func recordCounterMetric() {
		LDObserve.shared.recordCount(
			metric: .init(name: "test-counter", value: 10.0)
		)
	}

	func recordIncrementalMetric() {
		LDObserve.shared.recordIncr(
			metric: .init(name: "test-incremental-counter", value: 12.0)
		)
	}

	func recordUpDownCounterMetric() {
		LDObserve.shared.recordUpDownCounter(
			metric: .init(name: "test-up-down-counter", value: 25.0)
		)
	}
	
	func recordLogWithContext() {
		let span = LDObserve.shared.startSpan(
			name: "log-context-demo",
			properties: ["demo": "log-with-context"]
		)
		let capturedContext = span.context
		span.end()

		// Simulate a detached task where OTel context is lost automatically.
		DispatchQueue.global(qos: .background).async {
			LDObserve.shared.recordLog(
				message: "Log with span context",
				severity: .warn,
				properties: ["source": "detached-queue-demo"],
				spanContext: capturedContext
			)
		}
	}

	func recordLogs() {
		LDObserve.shared.recordLog(
			message: "logs-button-pressed",
			severity: .info,
			properties: [
				"test-string": "swift",
				"test-true": true,
				"test-false": false,
				"test-integer": 42,
				"test-long": 9_000_000_000,
				"test-double": 3.14,
				"test-array": [3.14],
				"test-nested": ["array": [1]]
			]
		)
	}
	
	func trackViaLDClient() {
		// Records a track span automatically via the Observability afterTrack hook.
		LDClient.get()?.track(
            key: "track-via-ld-client",
            data: [
                "test-string": "ios",
                "test-true": true,
                "test-false": false,
                "test-integer": .number(42),
                "test-double": 3.14,
                "test-long-number": .number(9_000_000_000_123),
            ]
        )
	}

	func trackViaLDObserve() {
		// Records a track span directly through the Observability API.
		LDObserve.shared.track(
			key: "track-via-ld-observe",
            properties: [
                "test-string": "ios",
                "test-true": true,
                "test-false": false,
                "test-integer": 42,
                // A 64-bit value beyond Int32 range (e.g. epoch nanoseconds),
                // demonstrating that long integers survive conversion.
                "test-long": 9_000_000_000_123,
                "test-double": 3.14,
                "test-swiftmap": ["test-string": "val"]
            ]
		)
	}

	func trackNested() {
		// A nested `track` payload following the Segment "Checkout Started"
		// example from analytics-taxonomy.md (§4.2): scalar fields plus a
		// `products` array of line-item objects.
		LDObserve.shared.track(
			key: "checkout-started",
			properties: [
				"name": "Checkout Started",
				"order_id": "ord_5521",
				"value": 72.0,
				"currency": "USD",
				"products": [
					["product_id": "SKU-1234", "quantity": 2, "price": 24.0],
					["product_id": "SKU-9876", "quantity": 1, "price": 24.0]
				]
			]
		)
	}

	func trackScreenView() {
		// Records a screen_view span manually; previous_screen is resolved through
		// the same shared screen stack used by automatic capture.
		screenViewCounter += 1
		LDObserve.shared.trackScreenView(
			name: "Manual Demo Screen \(screenViewCounter)",
			screenClass: "MainMenuView",
			screenId: "main-menu-demo-\(screenViewCounter)",
			category: "Demo",
			properties: [
				"source": "manual-demo",
				"index": screenViewCounter
			]
		)
	}

	/// Produces the selected scenario. In `.error` mode a catchable scenario is
	/// caught and reported via the SDK (returns normally); in `.crash` mode (or
	/// for non-catchable scenarios) the failure terminates the process.
	func trigger(scenario: CrashScenario, mode: CrashScenario.Mode) {
		if mode != .crash, scenario.supportsHandled {
			do {
				try runCatchable(scenario)
			} catch {
				switch mode {
				case .error:
					// Report the original error; the structured wrapper only
					// carries the throw-site backtrace for `.errorStructured`.
					LDObserve.shared.recordError((error as? StructuredError)?.underlying ?? error, attributes: [:])
				case .errorStructured:
					recordStructuredError(error)
				case .crash:
					break
				}
			}
			return
		}

		switch scenario {
		case .throwingError:
			_ = try! Self.alwaysThrows()
		case .castFailure:
			let anyValue: Any = "not an int"
			_ = anyValue as! Int
		case .decodingFailure:
			_ = try! JSONDecoder().decode([Int].self, from: Data("not json".utf8))
		case .fatalError:
			fatalError("iOS: Crash - intentional fatalError()")
		case .forceUnwrapNil:
			let value: String? = nil
			_ = value!
		case .arrayOutOfBounds:
			let numbers = [1, 2, 3]
			_ = numbers[numbers.count + 5]
		case .preconditionFailure:
			preconditionFailure("iOS: Crash - intentional precondition failure")
		case .assertionFailure:
			assertionFailure("iOS: Crash - intentional assertion failure")
		case .integerOverflow:
			// `Int.random` keeps the compiler from constant-folding (and rejecting)
			// the overflow at build time; the trap happens at runtime instead.
			var maxValue = Int.max
			maxValue += Int.random(in: 1...1)
			_ = maxValue
		case .badMemoryAccess:
			// A non-nil but unmapped address, so the force-unwrap succeeds and the
			// write faults with EXC_BAD_ACCESS / SIGSEGV.
			let pointer = UnsafeMutablePointer<Int>(bitPattern: 0x1)!
			pointer.pointee = 42
		case .abortSignal:
			abort()
		case .illegalInstruction:
			raise(SIGILL)
		case .nsException:
			// Objective-C NSRangeException, captured by KSCrash's nsException monitor.
			let empty = NSArray()
			_ = empty.object(at: 5)
		case .stackOverflow:
			_ = Self.infiniteRecursion(0)

		case .backgroundThreadCrash:
			// Crashes on a background queue while the main thread stays alive, so
			// the report contains multiple threads and the crashed one is not #0.
			DispatchQueue.global(qos: .userInitiated).async {
				fatalError("iOS: Crash - intentional crash on a background thread")
			}
		case .backgroundBadAccess:
			DispatchQueue.global(qos: .userInitiated).async {
				let pointer = UnsafeMutablePointer<Int>(bitPattern: 0x1)!
				pointer.pointee = 42
			}
		case .detachedTaskCrash:
			Task.detached(priority: .high) {
				fatalError("iOS: Crash - intentional crash in a detached Task")
			}
		case .concurrentMutation:
			// Unsynchronized concurrent access to a value-type Array from many
			// threads. Best-effort: usually faults (bad access / malloc / index),
			// occasionally survives — tap again if nothing happens.
			var shared = [Int]()
			DispatchQueue.concurrentPerform(iterations: 100_000) { index in
				shared.append(index)
				_ = shared.first
			}
			_ = shared
		case .busyThreadsThenCrash:
			// Spin up several long-lived busy threads so the crash report is rich
			// with threads, then crash on a background thread shortly after.
			for index in 0..<4 {
				Thread.detachNewThread {
					Thread.current.name = "ld-busy-\(index)"
					while true { _ = (0..<10_000).reduce(0, +) }
				}
			}
			DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
				fatalError("iOS: Crash - crash with many threads active")
			}
		}
	}

	/// The throwing form of each catchable scenario, shared by the handled-error
	/// path. Its crash counterparts (`try!`, `as!`) live in `trigger`.
	private func runCatchable(_ scenario: CrashScenario) throws {
		switch scenario {
		case .throwingError:
			_ = try Self.alwaysThrows()
		case .castFailure:
			_ = try Self.cast("not an int", to: Int.self)
		case .decodingFailure:
			// JSONDecoder throws its own error, so capture the backtrace here (at
			// the failing call) and rewrap before it unwinds past this frame.
			do {
				_ = try JSONDecoder().decode([Int].self, from: Data("not json".utf8))
			} catch {
				throw StructuredError(underlying: error, stackTraceJSON: LiveBacktrace.applePayloadJSON())
			}
		default:
			break
		}
	}

	/// Reports a handled error whose stacktrace is the structured `ld-apple-1`
	/// payload from the live call stack, so the backend symbolicates it from the
	/// uploaded dSYM — the non-fatal analog of a crash. Uses the same log +
	/// `exception.*` attribute shape the crash reporter emits.
	private func recordStructuredError(_ error: Error) {
		let underlying = (error as? StructuredError)?.underlying ?? error
		// Prefer the backtrace captured at the throw site. Fall back to a live
		// capture only for errors that weren't wrapped — that trace reflects the
		// reporting path, not the failure, but is better than none.
		let stackTraceJSON = (error as? StructuredError)?.stackTraceJSON ?? LiveBacktrace.applePayloadJSON()
		LDObserve.shared.recordLog(
			message: underlying.localizedDescription,
			severity: .error,
			properties: [
				"exception.type": String(describing: underlying),
				"exception.message": underlying.localizedDescription,
				"exception.stacktrace": stackTraceJSON,
			]
		)
	}

	private static func alwaysThrows() throws -> Int {
		// Capture the backtrace here, at the throw site, so `.errorStructured`
		// reports these frames rather than the unwound reporting path.
		throw StructuredError(underlying: Failure.crash, stackTraceJSON: LiveBacktrace.applePayloadJSON())
	}

	private static func cast<T>(_ value: Any, to type: T.Type) throws -> T {
		guard let result = value as? T else {
			throw StructuredError(underlying: Failure.cast, stackTraceJSON: LiveBacktrace.applePayloadJSON())
		}
		return result
	}

	// The `+ depth` keeps the call from being tail-call optimized away, so the
	// stack actually grows until it overflows. The `depth < 0` guard is never hit
	// (depth only grows) but stops the compiler from flagging guaranteed infinite
	// recursion.
	private static func infiniteRecursion(_ depth: Int) -> Int {
		if depth < 0 { return 0 }
		return infiniteRecursion(depth + 1) + depth
	}
	
	@MainActor
	func performNetworkRequest() async {
		guard !isNetworkInProgress else { return }
		isNetworkInProgress = true
		defer { isNetworkInProgress = false }
		
		let url = URL(string: "https://launchdarkly.com/")!
		do {
			_ = try await URLSession.shared.data(from: url)
		} catch {
			// ignore errors for demo
		}
	}
    
    func identifyUser() {
        do {
            var contextBuilder = LDContextBuilder(
                key: "single-userkey"
            )
            contextBuilder.kind("user")
            contextBuilder.trySetValue("firstName", "Bob")
            contextBuilder.trySetValue("lastName", "Bobberson")
            let newContext = try contextBuilder.build().get()
            _ = LDClient.get()?.identify(context: newContext) { result in
                print("result=", result)
            }
        } catch {
            print(error)
        }
    }
    
    func identifyAnonymous() {
        do {
            var contextBuilder = LDContextBuilder()
            contextBuilder.anonymous(false)
            let newContext = try contextBuilder.build().get()
            _ = LDClient.get()?.identify(context: newContext) { result in
                print("result=", result)
            }
        } catch {
            print(error)
        }
    }
    
    func identifyMulti() {
        let username = "multi-username"
        let id = "654321"
        var userBuilder = LDContextBuilder(key: username)
        userBuilder.kind("user")
        userBuilder.name(username)
        userBuilder.anonymous(false)
        userBuilder.trySetValue("customerNumber", .string(id))
        userBuilder.trySetValue("firstName", "Bob")
        userBuilder.trySetValue("lastName", "Bobberson")
        userBuilder.trySetValue("email", "multi@multi.com")
        
        var deviceBuilder = LDContextBuilder(key: "iphone")
        deviceBuilder.kind("device")
        deviceBuilder.name("iphone")
        deviceBuilder.anonymous(false)
        deviceBuilder.trySetValue("platform", .string("ios"))
        deviceBuilder.trySetValue("appVersion", .string("10.3.2.1"))
        
        let userContext = try? userBuilder.build().get()
        let deviceContext = try? deviceBuilder.build().get()
        
        var multiBuilder = LDMultiContextBuilder()
        multiBuilder.addContext(userContext!)
        multiBuilder.addContext(deviceContext!)
        
        let multiContext = try? multiBuilder.build().get()
        LDClient.get()?.identify(context: multiContext!) { error in
            print(error)
        }
    }
}

