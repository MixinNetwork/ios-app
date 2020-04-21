import UIKit

class SettingsSection {
    
    var footer: String?
    var rows: [SettingsRow]
    
    init(footer: String?, rows: [SettingsRow]) {
        self.footer = footer
        self.rows = rows
    }
    
}
