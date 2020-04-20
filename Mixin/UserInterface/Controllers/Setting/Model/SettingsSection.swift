import UIKit

class SettingsSection {
    
    let footer: String?
    let rows: [SettingsRow]
    
    init(footer: String?, rows: [SettingsRow]) {
        self.footer = footer
        self.rows = rows
    }
    
}
