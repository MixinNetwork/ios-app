import UIKit

class SettingsSection {
    
    var header: String?
    var footer: String?
    var rows: [SettingsRow]
    
    init(header: String? = nil, footer: String? = nil, rows: [SettingsRow]) {
        self.header = header
        self.footer = footer
        self.rows = rows
    }
    
}
