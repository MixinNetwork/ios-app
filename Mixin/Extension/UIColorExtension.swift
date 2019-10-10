import UIKit

extension UIColor {

    static let theme = UIColor(rgbValue: 0x397EE4)
    static let darkTheme = UIColor(rgbValue: 0x0CAAF5)
    static let backgroundGray = UIColor(rgbValue: 0xf5f5f5)
    static let infoGray = UIColor(rgbValue: 0x7799A9)
    static let error = UIColor(rgbValue: 0xd73449)
    static let placeholder = UIColor(red: 0, green: 0, blue: 0.1, alpha: 0.22)
    static let messageKeywordHighlight = UIColor(rgbValue: 0xC4EF6E)
    static let selectedLinkBackground = UIColor.black.withAlphaComponent(0.1)
    static let systemTint = UIColor(rgbValue: 0x007AFF)
    static let cameraSendBlue = UIColor(displayP3RgbValue: 0x3D75E3)
    static let selection = UIColor(rgbValue: 0xEDEEEE)
    static let accessoryText = UIColor(rgbValue: 0xBBBEC3)
    static let darkText = R.color.dark_text()!
    static let actionText = UIColor(displayP3RgbValue: 0x4B7CDD)
    static let highlightedText = R.color.highlighted_text()!
    static let descriptionText = UIColor(displayP3RgbValue: 0xBBBEC2)
    static let shadow = UIColor(rgbValue: 0xC3C3C3)
    
    static let walletGreen = UIColor(rgbValue: 0x29BE73)
    static let walletRed = UIColor(displayP3RgbValue: 0xF67070)
    static let walletGray = UIColor(rgbValue: 0xAAAAAA)
    
    static let hintBlue = UIColor(rgbValue: 0x1FB4FC)
    static let hintRed = UIColor(rgbValue: 0xFF7070)
    static let hintGreen = UIColor(rgbValue: 0x48CF94)
    
    static let modernCellSelection = UIColor(rgbValue: 0xF6F8FC)
    
    static let indicatorGray = UIColor(displayP3RgbValue: 0xBCBEC3)
    static let disabledGray = UIColor(displayP3RgbValue: 0xE5E7EC)
    
    static let usernameColors = [UIColor(rgbValue: 0xAA4848),
                                 UIColor(rgbValue: 0xB0665E),
                                 UIColor(rgbValue: 0xEF8A44),
                                 UIColor(rgbValue: 0xA09555),
                                 UIColor(rgbValue: 0x727234),
                                 UIColor(rgbValue: 0x9CAD23),
                                 UIColor(rgbValue: 0xAA9100),
                                 UIColor(rgbValue: 0xC49B4B),
                                 UIColor(rgbValue: 0xA47758),
                                 UIColor(rgbValue: 0xDF694C),
                                 UIColor(rgbValue: 0xD65859),
                                 UIColor(rgbValue: 0xC2405A),
                                 UIColor(rgbValue: 0xA75C96),
                                 UIColor(rgbValue: 0xBD637C),
                                 UIColor(rgbValue: 0x8F7AC5),
                                 UIColor(rgbValue: 0x7983C2),
                                 UIColor(rgbValue: 0x728DB8),
                                 UIColor(rgbValue: 0x5977C2),
                                 UIColor(rgbValue: 0x5E6DA2),
                                 UIColor(rgbValue: 0x3D98D0),
                                 UIColor(rgbValue: 0x5E97A1),
                                 UIColor(rgbValue: 0x4EABAA),
                                 UIColor(rgbValue: 0x63A082),
                                 UIColor(rgbValue: 0x877C9B),
                                 UIColor(rgbValue: 0xAA66C3),
                                 UIColor(rgbValue: 0xBB5334),
                                 UIColor(rgbValue: 0x667355),
                                 UIColor(rgbValue: 0x668899),
                                 UIColor(rgbValue: 0x83BE44),
                                 UIColor(rgbValue: 0xBBA600),
                                 UIColor(rgbValue: 0x429AB6),
                                 UIColor(rgbValue: 0x75856F),
                                 UIColor(rgbValue: 0x88A299),
                                 UIColor(rgbValue: 0xB3798E),
                                 UIColor(rgbValue: 0x447899),
                                 UIColor(rgbValue: 0xD79200),
                                 UIColor(rgbValue: 0x728DB8),
                                 UIColor(rgbValue: 0xDD637C),
                                 UIColor(rgbValue: 0x887C66),
                                 UIColor(rgbValue: 0xBE6C2C),
                                 UIColor(rgbValue: 0x9B6D77),
                                 UIColor(rgbValue: 0xB69370),
                                 UIColor(rgbValue: 0x976236),
                                 UIColor(rgbValue: 0x9D77A5),
                                 UIColor(rgbValue: 0x8A660E),
                                 UIColor(rgbValue: 0x5E935E),
                                 UIColor(rgbValue: 0x9B8484),
                                 UIColor(rgbValue: 0x92B288)]
    
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
