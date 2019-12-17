import UIKit

extension UIFont {
    
    static func dinCondensedBold(ofSize size: CGFloat) -> UIFont {
        return UIFont(name: "DINCondensed-Bold", size: size) ?? .systemFont(ofSize: size)
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
