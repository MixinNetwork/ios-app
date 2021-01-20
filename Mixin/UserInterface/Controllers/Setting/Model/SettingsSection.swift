import UIKit

class SettingsSection: NSObject {
    
    static let footerDidChangeNotification = Notification.Name("one.mixin.messenger.settings.section.footer.change")
    
    let header: String?
    var footer: String? {
        didSet {
            NotificationCenter.default.post(onMainThread: Self.footerDidChangeNotification, object: self, userInfo: nil)
        }
    }
    var rows: [SettingsRow]
    
    init(header: String? = nil, footer: String? = nil, rows: [SettingsRow]) {
        self.header = header
        self.footer = footer
        self.rows = rows
    }
    
}
