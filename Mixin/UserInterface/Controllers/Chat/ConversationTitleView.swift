import UIKit

final class ConversationTitleView: UIView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!
    
    private weak var effectView: UIVisualEffectView?
    
    override var intrinsicContentSize: CGSize {
        let contentSize = contentStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let height = contentSize.height + contentTopConstraint.constant + contentBottomConstraint.constant
        let horizontalPadding = effectView == nil
            ? contentLeadingConstraint.constant + contentTrailingConstraint.constant
            : height
        return CGSize(width: contentSize.width + horizontalPadding, height: height)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        intrinsicContentSize
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if #available(iOS 26, *) {
            let effect = UIGlassEffect()
            let effectView = UIVisualEffectView(effect: effect)
            insertSubview(effectView, at: 0)
            effectView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            self.effectView = effectView
            contentTopConstraint.constant = 4
            contentBottomConstraint.constant = 4
        }
    }
    
    override func layoutSubviews() {
        if let effectView {
            let cornerRadius = bounds.height / 2
            effectView.layer.cornerRadius = cornerRadius
            contentLeadingConstraint.constant = cornerRadius
            contentTrailingConstraint.constant = cornerRadius
        }
        super.layoutSubviews()
    }
    
}
