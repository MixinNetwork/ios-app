import Foundation

enum UserInterfaceStyle: String {
    
    static var current: UserInterfaceStyle {
        UserInterfaceStyle(style: UIScreen.main.traitCollection.userInterfaceStyle)
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
