import UIKit

final class ConversationTitleView: UIControl {
    
    @IBOutlet weak var contentControl: UIControl!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    
    override var isEnabled: Bool {
        didSet {
            contentControl?.isEnabled = isEnabled
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let contentControl = contentControl!
        contentControl.isEnabled = isEnabled
        contentControl.addAction(
            UIAction { [weak self] _ in
                self?.sendActions(for: .touchUpInside)
            },
            for: .touchUpInside,
        )
        if #available(iOS 26, *) {
            let effect = UIGlassEffect()
            effect.isInteractive = true
            let effectView = UIVisualEffectView(effect: effect)
            effectView.cornerConfiguration = .capsule()
            // Keep the touch target inside the glass so it can react to interactions.
            contentControl.removeFromSuperview()
            insertSubview(effectView, at: 0)
            effectView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            effectView.contentView.addSubview(contentControl)
            contentControl.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            contentLeadingConstraint.constant = 16
            contentTrailingConstraint.constant = 16
        } else {
            contentLeadingConstraint.constant = 8
            contentTrailingConstraint.constant = 8
        }
    }
    
}
