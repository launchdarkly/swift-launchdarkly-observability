import Foundation

public typealias ReducerFn<S, A> = (inout S, A) -> Void
public final class Store<S, A> {
    private let queue = DispatchQueue(label: "com.launchdarkly.store.queue")
    private var _state: S
    public var state: S {
        get {
            queue.sync { _state }
        }
        set {
            queue.sync { _state = newValue }
        }
    }
    private let reducer: ReducerFn<S, A>

    public init(
        state: S,
        reducer: @escaping ReducerFn<S, A>
    ) {
        self._state = state
        self.reducer = reducer
    }

    public func dispatch(_ action: A) {
        reducer(&state, action)
    }
}
