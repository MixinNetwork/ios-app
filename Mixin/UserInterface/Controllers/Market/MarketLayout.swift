import Foundation

enum MarketLayout {
    
    static let mainItemLeadingMargin: CGFloat = 44
    
    static let priceItemWidth: CGFloat = switch ScreenWidth.current {
    case .long, .medium:
        90
    case .short:
        80
    }
    static let priceItemTrailingMargin: CGFloat = switch ScreenWidth.current {
    case .long, .medium:
        20
    case .short:
        8
    }
    
    static let changeItemWidth: CGFloat = 60
    static let changeItemTrailingMargin: CGFloat = 16
    
}
