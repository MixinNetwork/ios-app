import UIKit
import Rswift

final class SettingsRow: NSObject {
    
    enum Style {
        case normal
        case highlighted
        case destructive
    }
    
    enum Accessory {
        case none
        case disclosure
        case `switch`(Bool)
        case checkmark(Bool)
    }
    
    static let subtitleDidChangeNotification = Notification.Name("one.mixin.messenger.settings.row.subtitle.change")
    static let accessoryDidChangeNotification = Notification.Name("one.mixin.messenger.settings.row.accessory.change")
    
    let icon: UIImage?
    let title: String
    let titleStyle: Style
    
    var subtitle: String? {
        didSet {
            NotificationCenter.default.postOnMain(name: Self.subtitleDidChangeNotification, object: self, userInfo: nil)
        }
    }
    
    var accessory: Accessory {
        didSet {
            NotificationCenter.default.postOnMain(name: Self.accessoryDidChangeNotification, object: self, userInfo: nil)
        }
    }
    
    init(icon: UIImage? = nil, title: String, titleStyle: Style = .normal, subtitle: String? = nil, accessory: Accessory = .none) {
        self.icon = icon
        self.title = title
        self.titleStyle = titleStyle
        self.subtitle = subtitle
        self.accessory = accessory
        super.init()
    }
    
}
