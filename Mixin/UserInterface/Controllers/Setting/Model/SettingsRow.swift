import UIKit

final class SettingsRow: NSObject {
    
    enum Style {
        case normal
        case highlighted
        case destructive
    }
    
    enum Subtitle {
        case text(String)
        case icon(UIImage)
    }
    
    enum Accessory {
        case none
        case disclosure
        case `switch`(isOn: Bool, isEnabled: Bool = true)
        case checkmark
        case busy
    }
    
    static let titleDidChangeNotification = Notification.Name("one.mixin.messenger.settings.row.title.change")
    static let subtitleDidChangeNotification = Notification.Name("one.mixin.messenger.settings.row.subtitle.change")
    static let accessoryDidChangeNotification = Notification.Name("one.mixin.messenger.settings.row.accessory.change")
    
    let icon: UIImage?
    
    var title: String {
        didSet {
            NotificationCenter.default.post(onMainThread: Self.titleDidChangeNotification, object: self, userInfo: nil)
        }
    }
    
    let titleStyle: Style
    
    var subtitle: Subtitle? {
        didSet {
            NotificationCenter.default.post(onMainThread: Self.subtitleDidChangeNotification, object: self, userInfo: nil)
        }
    }
    
    var accessory: Accessory {
        didSet {
            NotificationCenter.default.post(onMainThread: Self.accessoryDidChangeNotification, object: self, userInfo: nil)
        }
    }
    
    let menu: UIMenu?
    
    init(
        icon: UIImage? = nil,
        title: String,
        titleStyle: Style = .normal,
        subtitle: String? = nil,
        accessory: Accessory = .none,
        menu: UIMenu? = nil
    ) {
        self.icon = icon
        self.title = title
        self.titleStyle = titleStyle
        self.subtitle = if let subtitle {
            .text(subtitle)
        } else {
            nil
        }
        self.accessory = accessory
        self.menu = menu
        super.init()
    }
    
    init(
        icon: UIImage? = nil,
        title: String,
        titleStyle: Style,
        subtitleIcon: UIImage,
        accessory: Accessory,
        menu: UIMenu? = nil
    ) {
        self.icon = icon
        self.title = title
        self.titleStyle = titleStyle
        self.subtitle = .icon(subtitleIcon)
        self.accessory = accessory
        self.menu = menu
    }
    
}
