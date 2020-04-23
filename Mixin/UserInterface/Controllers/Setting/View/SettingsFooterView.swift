import UIKit

class SettingsFooterView: SettingsHeaderFooterView {
    
    override func prepare() {
        super.prepare()
        label.backgroundColor = .clear
        label.textColor = .accessoryText
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
    }
    
}
