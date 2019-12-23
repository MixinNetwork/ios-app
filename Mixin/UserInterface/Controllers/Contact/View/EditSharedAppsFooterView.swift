import UIKit

class EditSharedAppsFooterView: SeparatorShadowFooterView {
    
    enum Style {
        case favorite
        case candidate
    }
    
    var style = Style.favorite {
        didSet {
            shadowView.hasLowerShadow = style == .favorite
            setNeedsLayout()
        }
    }
    
    override func layoutShadowViewAndLabel() {
        switch style {
        case .favorite:
            shadowView.bounds.size = CGSize(width: bounds.width, height: 10)
            shadowView.center = CGPoint(x: bounds.midX, y: bounds.midY)
            backgroundView?.backgroundColor = .background
            shadowView.backgroundColor = .secondaryBackground
        case .candidate:
            super.layoutShadowViewAndLabel()
            shadowView.center.y += 15
            label.center.y += 15
            backgroundView?.backgroundColor = .secondaryBackground
            shadowView.backgroundColor = .clear
        }
    }
    
    override func prepare() {
        super.prepare()
        shadowView.clipsToBounds = true
    }
    
}
