import UIKit

final class OverlayTipView: UIView {
    
    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var backgroundImageViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundImageViewTopConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeFromSuperview()
        super.touchesBegan(touches, with: event)
    }
    
    func placeTip(at point: CGPoint) {
        backgroundImageViewLeftConstraint.constant = point.x - 46
        backgroundImageViewTopConstraint.constant = point.y
        layoutIfNeeded()
    }
    
}
