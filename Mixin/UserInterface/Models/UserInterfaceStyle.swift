import UIKit

enum UserInterfaceStyle: String {
    
    static var current: UserInterfaceStyle {
        if let scene = UIApplication.shared.firstWindowScene,
           let window = scene.keyWindow,
           window.overrideUserInterfaceStyle != .unspecified
        {
            UserInterfaceStyle(style: window.overrideUserInterfaceStyle)
        } else {
            UserInterfaceStyle(style: UIScreen.main.traitCollection.userInterfaceStyle)
        }
    }
    
    case light, dark
    
    init(style: UIUserInterfaceStyle) {
        switch style {
        case .unspecified, .light:
            self = .light
        case .dark:
            self = .dark
        @unknown default:
            self = .light
        }
    }
    
}
