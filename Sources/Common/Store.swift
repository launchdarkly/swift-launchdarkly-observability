import Foundation

public typealias ReducerFn<S, A> = (inout S, A) -> Void
public final class Store<S, A> {
    public var state: S
    private let reducer: ReducerFn<S, A>

    public init(
        state: S,
        reducer: @escaping ReducerFn<S, A>
    ) {
        self.state = state
        self.reducer = reducer
    }

    public func dispatch(_ action: A) {
        reducer(&state, action)
    }
}
