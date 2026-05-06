import UIKit

extension UIFont {
    
    static func condensed(size: CGFloat) -> UIFont {
        return UIFont(name: "Mixin Condensed", size: size) ?? .systemFont(ofSize: size)
    }
    
}

extension UIFont.Weight {
    
    static func accessiblityBoldTextCounterWeight(_ weight: UIFont.Weight) -> UIFont.Weight {
        guard UIAccessibility.isBoldTextEnabled else {
            return weight
        }
        return switch weight {
        case .black:
                .bold
        case .heavy:
                .semibold
        case .bold:
                .medium
        case .semibold:
                .regular
        case .medium:
                .light
        case .regular:
                .light
        case .light:
                .thin
        case .thin:
                .ultraLight
        default:
                .light
        }
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
