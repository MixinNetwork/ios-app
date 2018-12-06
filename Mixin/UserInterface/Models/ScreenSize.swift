import UIKit

enum ScreenSize {
    
    case inch3_5
    case inch4
    case inch4_7
    case inch5_5
    case inch5_8
    case inch6_1
    case inch6_5
    case unknown
    
    static let current: ScreenSize = {
        let screenHeight = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        switch screenHeight {
        case 480:
            return .inch3_5
        case 568:
            return .inch4
        case 667:
            return .inch4_7
        case 736:
            return .inch5_5
        case 812:
            return .inch5_8
        case 896:
            return UIScreen.main.scale == 3 ? .inch6_5 : .inch6_1
        default:
            return .unknown
        }
    }()
    
    static let defaultKeyboardHeight: CGFloat = {
        return keyboardHeight[.current] ?? 271
    }()
    
    static let minReasonableKeyboardHeight = keyboardHeight.values.min() ?? 271
    
    private static let keyboardHeight: [ScreenSize: CGFloat] = [
        .inch6_5: 346,
        .inch6_1: 346,
        .inch5_8: 335,
        .inch5_5: 271,
        .inch4_7: 260,
        .inch4: 253,
        .inch3_5: 261
    ]
    
}
