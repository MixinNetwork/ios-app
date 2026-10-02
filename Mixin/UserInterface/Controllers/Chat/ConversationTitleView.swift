import UIKit

final class ConversationTitleView: UIView {
    
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    
    private weak var effectView: UIVisualEffectView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if #available(iOS 26, *) {
            let effectView = UIVisualEffectView(effect: UIGlassEffect())
            effectView.isUserInteractionEnabled = false
            effectView.clipsToBounds = true
            effectView.layer.cornerCurve = .continuous
            insertSubview(effectView, at: 0)
            effectView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            self.effectView = effectView
            
            contentLeadingConstraint.constant = 16
            contentTrailingConstraint.constant = 16
        } else {
            contentLeadingConstraint.constant = 8
            contentTrailingConstraint.constant = 8
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        effectView?.layer.cornerRadius = bounds.height / 2
    }
    
}
