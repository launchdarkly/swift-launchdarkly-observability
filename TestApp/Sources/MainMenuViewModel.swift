import Foundation
import LaunchDarkly
import LaunchDarklyObservability

final class MainMenuViewModel: ObservableObject {
	@Published var isNetworkInProgress: Bool = false
	
	func recordError() {
		LDObserve.shared.recordError(
			error: Failure.crash,
			attributes: [:]
		)
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
	
	func recordCounterMetric() {
		LDObserve.shared.recordCount(
			metric: .init(
				name: "press-count",
				value: 1,
				timestamp: .now
			)
		)
	}
	
	func recordLogs() {
		LDObserve.shared.recordLog(
			message: "logs-button-pressed",
			severity: .info,
			attributes: ["testuser": .string("andrey")]
		)
	}
	
	func crash() -> Never {
		fatalError()
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

