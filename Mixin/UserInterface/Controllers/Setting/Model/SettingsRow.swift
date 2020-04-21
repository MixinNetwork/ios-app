import UIKit
import Rswift

class SettingsRow: NSObject {
    
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
    
    init(icon: UIImage? = nil, title: String, subtitle: String? = nil, accessory: Accessory = .none) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
        super.init()
    }
    
}
