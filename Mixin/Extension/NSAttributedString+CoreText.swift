import Foundation

extension NSAttributedString.Key {
    static let ctFont = kCTFontAttributeName as NSAttributedString.Key
    static let ctForegroundColor = kCTForegroundColorAttributeName as NSAttributedString.Key
    static let ctParagraphStyle = kCTParagraphStyleAttributeName as NSAttributedString.Key
}

extension NSMutableAttributedString {
    
    func setCTForegroundColor(_ color: UIColor, for range: NSRange) {
        removeAttribute(.ctForegroundColor, range: range)
        addAttributes([.ctForegroundColor: color.cgColor], range: range)
    }
    
}
