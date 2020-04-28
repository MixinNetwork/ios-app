import UIKit

class SettingsHeaderView: SettingsHeaderFooterView {
    
    override class var textColor: UIColor {
        .accessoryText
    }

    override class var textStyle: UIFont.TextStyle {
        .footnote
    }
    
    override class var labelInsets: UIEdgeInsets {
        UIEdgeInsets(top: 20, left: 20, bottom: 11, right: 20)
    }
    
}
