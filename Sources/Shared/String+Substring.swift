extension String {
    public func substring(offset: Int, length: UInt) -> String {
        if abs(offset) > self.count {
            return Self(Substring())
        }
        
        var startIdx: String.Index
        if offset < 0 {
            startIdx = self.index(self.endIndex, offsetBy: offset)
            
            if length >= abs(offset) {
                return Self(self[startIdx...])
            }
        } else {
            startIdx = self.index(self.startIndex, offsetBy: offset)
            
            if length > (self.count - offset) {
                return Self(self[startIdx...])
            }
        }
        
        let endIdx = self.index(startIdx, offsetBy: Int(length))
        return Self(self[startIdx..<endIdx])
    }
}
