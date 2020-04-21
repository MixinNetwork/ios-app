import UIKit
import Rswift

protocol SettingsRowObserver: class {
    
    func settingsRow(_ row: SettingsRow, subtitleDidChangeTo newValue: String?)
    
}

class SettingsRow: NSObject {
    
    enum Accessory {
        case none
        case disclosure
        case `switch`(Bool)
        case checkmark(Bool)
    }
    
    weak var observer: SettingsRowObserver?
    
    let icon: UIImage?
    let title: String
    var subtitle: String? {
        didSet {
            observer?.settingsRow(self, subtitleDidChangeTo: subtitle)
        }
    }
    let accessory: Accessory
    
    init(icon: UIImage? = nil, title: String, subtitle: String? = nil, accessory: Accessory = .none) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
        super.init()
    }
    
}
