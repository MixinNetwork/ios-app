import UIKit

class SettingsHeaderView: SettingsHeaderFooterView {
    
    override class var textColor: UIColor {
        .text
    }
    
    override class var textStyle: UIFont.TextStyle {
        .callout
    }
    
    override class var labelInsets: UIEdgeInsets {
        UIEdgeInsets(top: 20, left: 20, bottom: 11, right: 20)
    }
    
}
