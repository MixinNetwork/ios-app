import Foundation

extension CFRange {
    
    static let zero = CFRange(location: 0, length: 0)
    
    init(nsRange: NSRange) {
        self = CFRange(location: nsRange.location, length: nsRange.length)
    }
    
}

extension NSRange {
    
    init(cfRange: CFRange) {
        self = NSRange(location: cfRange.location, length: cfRange.length)
    }
    
}
