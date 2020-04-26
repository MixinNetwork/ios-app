import UIKit

class SettingsHeaderView: SettingsHeaderFooterView {
    
    static let attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: UIColor.text,
        .font: UIFont.preferredFont(forTextStyle: .callout)
    ]
    
    override class var labelInsets: UIEdgeInsets {
        UIEdgeInsets(top: 20, left: 20, bottom: 11, right: 20)
    }
    
    override var textAttributes: [NSAttributedString.Key : Any] {
        Self.attributes
    }
    
}
