import UIKit
import Rswift

class SettingsRow {
    
    enum Accessory {
        case none
        case disclosure
        case `switch`(Bool)
        case checkmark(Bool)
    }
    
    let icon: UIImage?
    let title: String
    var subtitle: String?
    let accessory: Accessory
    
    init(icon: UIImage? = nil, title: String, subtitle: String? = nil, accessory: Accessory = .none) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }
    
}
