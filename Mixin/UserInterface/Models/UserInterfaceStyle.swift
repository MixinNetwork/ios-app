import Foundation

enum UserInterfaceStyle: String {
    
    static var current: UserInterfaceStyle {
        if #available(iOS 13.0, *), AppDelegate.current.mainWindow.overrideUserInterfaceStyle != .unspecified {
            return UserInterfaceStyle(style: AppDelegate.current.mainWindow.overrideUserInterfaceStyle)
        } else {
            return UserInterfaceStyle(style: UIScreen.main.traitCollection.userInterfaceStyle)
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
