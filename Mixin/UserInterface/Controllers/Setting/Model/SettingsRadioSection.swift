import UIKit

class SettingsRadioSection: SettingsSection {
    
    func setAccessory(_ accessory: SettingsRow.Accessory, forRowAt index: Int) {
        for (rowIndex, row) in rows.enumerated() {
            row.accessory = rowIndex == index ? accessory : .none
        }
    }
    
    func removeAllAccessories() {
        for row in rows {
            row.accessory = .none
        }
    }
    
}
