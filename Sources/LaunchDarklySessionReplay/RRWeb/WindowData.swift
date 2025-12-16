import Foundation

struct WindowData: EventDataProtocol {
    var href: String?
    var width: Int?
    var height: Int?
    
    init(href: String? = nil, width: Int? = nil, height: Int? = nil) {
        self.href = href
        self.width = width
        self.height = height
    }
}
