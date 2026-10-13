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
    
    func writeJSON(to writer: JSONWriter) {
        writer.beginObject()
        writer.writeIfPresent("href", href)
        writer.writeIfPresent("width", width)
        writer.writeIfPresent("height", height)
        writer.endObject()
    }
}
