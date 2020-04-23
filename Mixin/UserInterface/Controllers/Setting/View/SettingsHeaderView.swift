import UIKit

class SettingsHeaderView: SettingsFooterView {
    
    override func prepare() {
        super.prepare()
        label.backgroundColor = .clear
        label.textColor = .text
        label.numberOfLines = 0
        label.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
    }
    
}
