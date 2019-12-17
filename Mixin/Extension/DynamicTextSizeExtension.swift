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
            case "regular16":
                titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .regular), adjustForContentSize: true)
            case "regular14":
                titleLabel?.setFont(scaledFor: .systemFont(ofSize: 14, weight: .regular), adjustForContentSize: true)
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
                font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 18, weight: .regular))
            case "regular16":
                font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 16, weight: .regular))
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
                font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 18, weight: .semibold))
            case "regular16":
                font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 16, weight: .regular))
            case "regular12":
                font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 12, weight: .regular))
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
