import Foundation

extension UIButton {

    @IBInspectable
    var dynamicTextSize: String? {
        get {
            return nil
        }
        set {
            guard let style = newValue, !style.isEmpty else {
                return
            }
            switch style {
            case "semibold14":
                titleLabel?.font = .scaledFont(ofSize: 14, weight: .semibold)
            case "regular16":
                titleLabel?.font = .scaledFont(ofSize: 16, weight: .regular)
            case "regular14":
                titleLabel?.font = .scaledFont(ofSize: 14, weight: .regular)
            default:
                break
            }
        }
    }

}

extension UITextField {

    @IBInspectable
    var dynamicTextSize: String? {
        get {
            return nil
        }
        set {
            guard let style = newValue, !style.isEmpty else {
                return
            }

            switch style {
            case "regular18":
                font = .scaledFont(ofSize: 18, weight: .regular)
            case "regular16":
                font = .scaledFont(ofSize: 16, weight: .regular)
            default:
                return
            }
            adjustsFontForContentSizeCategory = true
        }
    }

}

extension UILabel {

    @IBInspectable
    var dynamicTextSize: String? {
        get {
            return nil
        }
        set {
            guard let style = newValue, !style.isEmpty else {
                return
            }
            switch style {
            case "semibold18":
                font = .scaledFont(ofSize: 18, weight: .semibold)
            case "semibold16":
                font = .scaledFont(ofSize: 16, weight: .semibold)
            case "semibold12":
                font = .scaledFont(ofSize: 12, weight: .semibold)
            case "regular18":
                font = .scaledFont(ofSize: 18, weight: .regular)
            case "regular16":
                font = .scaledFont(ofSize: 16, weight: .regular)
            case "regular14":
                font = .scaledFont(ofSize: 14, weight: .regular)
            case "regular12":
                font = .scaledFont(ofSize: 12, weight: .regular)
            case "light14":
                font = .scaledFont(ofSize: 14, weight: .light)
            default:
                return
            }
            adjustsFontForContentSizeCategory = true
        }
    }

    func setFont(scaledFor font: UIFont, adjustForContentSize: Bool) {
         self.font = UIFontMetrics.default.scaledFont(for: font)
         self.adjustsFontForContentSizeCategory = adjustForContentSize
     }
}

extension UIFont {

    class func scaledFont(ofSize fontSize: CGFloat, weight: UIFont.Weight) -> UIFont {
        return UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: fontSize, weight: weight))
    }

    func scaled() -> UIFont {
        return UIFontMetrics.default.scaledFont(for: self)
    }

}
