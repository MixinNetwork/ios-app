import UIKit

class SettingsFooterView: SettingsHeaderFooterView {
    
    static let attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: UIColor.accessoryText,
        .font: UIFont.preferredFont(forTextStyle: .caption1)
    ]
    
    override class var labelInset: UIEdgeInsets {
        UIEdgeInsets(top: 12, left: 20, bottom: 11, right: 20)
    }
    
    override var textAttributes: [NSAttributedString.Key : Any] {
        Self.attributes
    }
    
}
