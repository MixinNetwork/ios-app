import UIKit

extension UIColor {
    
    static let background = R.color.background()!
    static let secondaryBackground = R.color.background_secondary()!
    static let inputBackground = R.color.background_input()!
    static let selectionBackground = R.color.background_selection()!
    static let mixinGreen = R.color.green()!
    static let mixinRed = R.color.red()!
    static let title = R.color.title()!
    static let text = R.color.text()!
    static let theme = R.color.theme()!

    static let accessoryText = R.color.text_accessory()!
    static let highlightedText = R.color.theme()!
    static let shadow = R.color.table_shadow()!
    static let chatText = R.color.chat_text()!

    static let infoGray = UIColor(rgbValue: 0x7799A9)
    static let error = UIColor(rgbValue: 0xd73449)
    static let selectedLinkBackground = UIColor.black.withAlphaComponent(0.1)
    static let systemTint = UIColor(rgbValue: 0x007AFF)
    static let cameraSendBlue = UIColor(displayP3RgbValue: 0x3D75E3)

    static let walletGreen = UIColor(rgbValue: 0x29BE73)
    static let walletRed = UIColor(displayP3RgbValue: 0xF67070)
    static let walletGray = UIColor(rgbValue: 0xAAAAAA)

    static let usernameColors = [UIColor(displayP3RgbValue: 0x8C8DFF),
                                 UIColor(displayP3RgbValue: 0x7983C2),
                                 UIColor(displayP3RgbValue: 0x6D8DDE),
                                 UIColor(displayP3RgbValue: 0x5979F0),
                                 UIColor(displayP3RgbValue: 0x6695DF),
                                 UIColor(displayP3RgbValue: 0x8F7AC5),
                                 UIColor(displayP3RgbValue: 0x9D77A5),
                                 UIColor(displayP3RgbValue: 0x8A64D0),
                                 UIColor(displayP3RgbValue: 0xAA66C3),
                                 UIColor(displayP3RgbValue: 0xA75C96),
                                 UIColor(displayP3RgbValue: 0xC8697D),
                                 UIColor(displayP3RgbValue: 0xB74D62),
                                 UIColor(displayP3RgbValue: 0xBD637C),
                                 UIColor(displayP3RgbValue: 0xB3798E),
                                 UIColor(displayP3RgbValue: 0x9B6D77),
                                 UIColor(displayP3RgbValue: 0xB87F7F),
                                 UIColor(displayP3RgbValue: 0xC5595A),
                                 UIColor(displayP3RgbValue: 0xAA4848),
                                 UIColor(displayP3RgbValue: 0xB0665E),
                                 UIColor(displayP3RgbValue: 0xB76753),
                                 UIColor(displayP3RgbValue: 0xBB5334),
                                 UIColor(displayP3RgbValue: 0xC97B46),
                                 UIColor(displayP3RgbValue: 0xBE6C2C),
                                 UIColor(displayP3RgbValue: 0xCB7F40),
                                 UIColor(displayP3RgbValue: 0xA47758),
                                 UIColor(displayP3RgbValue: 0xB69370),
                                 UIColor(displayP3RgbValue: 0xA49373),
                                 UIColor(displayP3RgbValue: 0xAA8A46),
                                 UIColor(displayP3RgbValue: 0xAA8220),
                                 UIColor(displayP3RgbValue: 0x76A048),
                                 UIColor(displayP3RgbValue: 0x9CAD23),
                                 UIColor(displayP3RgbValue: 0xA19431),
                                 UIColor(displayP3RgbValue: 0xAA9100),
                                 UIColor(displayP3RgbValue: 0xA09555),
                                 UIColor(displayP3RgbValue: 0xC49B4B),
                                 UIColor(displayP3RgbValue: 0x5FB05F),
                                 UIColor(displayP3RgbValue: 0x6AB48F),
                                 UIColor(displayP3RgbValue: 0x71B15C),
                                 UIColor(displayP3RgbValue: 0xB3B357),
                                 UIColor(displayP3RgbValue: 0xA3B561),
                                 UIColor(displayP3RgbValue: 0x909F45),
                                 UIColor(displayP3RgbValue: 0x93B289),
                                 UIColor(displayP3RgbValue: 0x3D98D0),
                                 UIColor(displayP3RgbValue: 0x429AB6),
                                 UIColor(displayP3RgbValue: 0x4EABAA),
                                 UIColor(displayP3RgbValue: 0x6BC0CE),
                                 UIColor(displayP3RgbValue: 0x64B5D9),
                                 UIColor(displayP3RgbValue: 0x3E9CCB),
                                 UIColor(displayP3RgbValue: 0x2887C4),
                                 UIColor(displayP3RgbValue: 0x52A98B)]
    
    convenience init(rgbValue: UInt, alpha: CGFloat = 1.0) {
        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                  alpha: alpha)
    }
    
    convenience init(displayP3RgbValue value: UInt, alpha: CGFloat = 1) {
        self.init(displayP3Red: CGFloat((value & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((value & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(value & 0x0000FF) / 255.0,
                  alpha: alpha)
    }
    
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt32()
        Scanner(string: hex).scanHexInt32(&int)
        let a, r, g, b: UInt32
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
    var image: UIImage? {
        let rect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        var image: UIImage?
        UIGraphicsBeginImageContext(rect.size)
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(cgColor)
            context.fill(rect)
            image = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()
        return image
    }
    
    // https://www.w3.org/WAI/ER/WD-AERT/#color-contrast
    var w3cLightness: CGFloat {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: nil)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
    
}
