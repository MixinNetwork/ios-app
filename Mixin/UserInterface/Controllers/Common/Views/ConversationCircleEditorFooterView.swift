import UIKit

class ConversationCircleEditorFooterView: SeparatorShadowFooterView {
    
    override func layoutShadowViewAndLabel() {
        shadowView.bounds.size = CGSize(width: bounds.width, height: 10)
        shadowView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    override func prepare() {
        super.prepare()
        shadowView.clipsToBounds = true
        shadowView.hasLowerShadow = true
        shadowView.backgroundColor = .secondaryBackground
        backgroundView?.backgroundColor = .background
    }
    
}
