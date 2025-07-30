extension String {
    public func padEnd<T>(toLength length: Int, withPad pad: T) -> Self where T: StringProtocol {
        self.padding(toLength: length, withPad: "0", startingAt: 0)
    }
}
