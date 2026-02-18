import Foundation

struct WindowData: EventDataProtocol {
    var href: String?
    var width: Int?
    var height: Int?
    
    init(href: String? = nil, size: CGSize) {
        self.href = href
        self.width = Int(size.width)
        self.height = Int(size.height)
    }
}
