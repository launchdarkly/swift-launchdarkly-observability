extension String {
    public func toHexString() throws -> String {
        guard let data = self.data(using: .utf8) else {
            throw NSError(domain: "Invalid UTF-8 encoding", code: 1, userInfo: nil)
        }
        return data.map { String(format: "%02x", $0) }.joined()
    }
}
