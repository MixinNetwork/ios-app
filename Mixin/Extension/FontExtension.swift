import UIKit

extension UIFont {
    
    static func condensed(size: CGFloat) -> UIFont {
        return UIFont(name: "Mixin Condensed", size: size) ?? .systemFont(ofSize: size)
    }
    
}

extension UIButton {
    
    @IBInspectable
    var adjustsFontForContentSizeCategory: Bool {
        set {
            titleLabel?.adjustsFontForContentSizeCategory = newValue
        }
        get {
            return titleLabel?.adjustsFontForContentSizeCategory ?? false
        }
    }
    
}
