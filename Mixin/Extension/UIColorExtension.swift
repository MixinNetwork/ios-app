import UIKit

extension UIColor {
    
    static let error = UIColor(rgbValue: 0xd73449)
    static let selectedLinkBackground = UIColor.black.withAlphaComponent(0.1)
    static let systemTint = UIColor(rgbValue: 0x007AFF)
    static let cameraSendBlue = UIColor(displayP3RgbValue: 0x3D75E3)
    
    static let walletGreen = UIColor(rgbValue: 0x29BE73)
    static let walletRed = UIColor(displayP3RgbValue: 0xF67070)
    static let walletGray = UIColor(rgbValue: 0xAAAAAA)
    
    static let tagBackground = UIColor.black.withAlphaComponent(0.16)
    
    static let usernameColors: [UIColor] = {
        let values: [UInt] = [
            0x8C8DFF, 0x7983C2, 0x6D8DDE, 0x5979F0, 0x6695DF, 0x8F7AC5,
            0x9D77A5, 0x8A64D0, 0xAA66C3, 0xA75C96, 0xC8697D, 0xB74D62,
            0xBD637C, 0xB3798E, 0x9B6D77, 0xB87F7F, 0xC5595A, 0xAA4848,
            0xB0665E, 0xB76753, 0xBB5334, 0xC97B46, 0xBE6C2C, 0xCB7F40,
            0xA47758, 0xB69370, 0xA49373, 0xAA8A46, 0xAA8220, 0x76A048,
            0x9CAD23, 0xA19431, 0xAA9100, 0xA09555, 0xC49B4B, 0x5FB05F,
            0x6AB48F, 0x71B15C, 0xB3B357, 0xA3B561, 0x909F45, 0x93B289,
            0x3D98D0, 0x429AB6, 0x4EABAA, 0x6BC0CE, 0x64B5D9, 0x3E9CCB,
            0x2887C4, 0x52A98B
        ]
        return values.map { UIColor(displayP3RgbValue: $0) }
    }()
    
    static let avatarBackgroundColors: [UIColor] = {
        let values: [UInt] = [
            0xFFD659, 0xFFC168, 0xF58268, 0xF4979C, 0xEC7F87, 0xFF78CB,
            0xC377E0, 0x8BAAFF, 0x78DCFA, 0x88E5B9, 0xBFF199, 0xC5E1A5,
            0xCD907D, 0xBE938E, 0xB68F91, 0xBC987B, 0xA69E8E, 0xD4C99E,
            0x93C2E6, 0x92C3D9, 0x8FBFC5, 0x80CBC4, 0xA4DBDB, 0xB2C8BD,
            0xF7C8C9, 0xDCC6E4, 0xBABAE8, 0xBABCD5, 0xAD98DA, 0xC097D9
        ]
        return values.map { UIColor(displayP3RgbValue: $0) }
    }()

    static let circleColors: [UIColor] = {
        let values: [UInt] = [
            0x8E7BFF, 0x657CFB, 0xA739C2, 0xBD6DDA, 0xFD89F1, 0xFA7B95,
            0xE94156, 0xFA9652, 0xF1D22B, 0xBAE361, 0x5EDD5E, 0x4BE6FF,
            0x45B7FE, 0x00ECD0, 0xFFCCC0, 0xCEA06B
        ]
        return values.map { UIColor(displayP3RgbValue: $0) }
    }()
    
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
