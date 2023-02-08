import Foundation

public enum ChatFontSize: Int {

    case extraSmall = 0
    case small = 1
    case medium = 2
    case regular = 3
    case large = 4
    case extraLarge = 5
    case extraExtraLarge = 6
    
    public init(size: CGFloat) {
        switch size {
        case 14: self = .extraSmall
        case 15: self = .small
        case 16: self = .medium
        case 17: self = .regular
        case 19: self = .large
        case 21: self = .extraLarge
        case 23: self = .extraExtraLarge
        default: self = .regular
        }
    }
    
    public var fontSize: Int {
        switch self {
        case .extraSmall:
            return 14
        case .small:
            return 15
        case .medium:
            return 16
        case .regular:
            return 17
        case .large:
            return 19
        case .extraLarge:
            return 21
        case .extraExtraLarge:
            return 23
        }
    }
    
}
