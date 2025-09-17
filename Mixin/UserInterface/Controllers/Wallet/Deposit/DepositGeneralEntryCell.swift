import UIKit
import MixinServices

final class DepositGeneralEntryCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var iconBackgroundView: UIView!
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var supportedTokensLabel: UILabel!
    @IBOutlet weak var actionStackView: UIStackView!
    
    @IBOutlet weak var qrCodeDimensionConstraint: NSLayoutConstraint!
    @IBOutlet weak var iconBackgroundDimensionConstraint: NSLayoutConstraint!
    
    weak var delegate: DepositEntryActionDelegate?
    
    private var actionButtons: [UIButton] = []
    private var actions: [DepositViewModel.Entry.Action] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        qrCodeView.setDefaultCornerCurve()
        qrCodeView.tintColor = .black
        iconBackgroundView.layer.cornerRadius = iconBackgroundDimensionConstraint.constant / 2
        iconBackgroundView.layer.masksToBounds = true
        iconBackgroundView.overrideUserInterfaceStyle = .light
        iconView.overrideUserInterfaceStyle = .light
        supportedTokensLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    func load<Token: OnChainToken>(
        content: DepositViewModel.Entry.Content,
        token: Token,
        supporting: String?,
        actions: [DepositViewModel.Entry.Action]
    ) {
        titleLabel.text = content.title
        contentLabel.font = {
            let font: UIFont = if content.textValue.count > 120 {
                .systemFont(ofSize: 12)
            } else if content.textValue.count > 100 {
                .systemFont(ofSize: 14)
            } else {
                .systemFont(ofSize: 16)
            }
            return UIFontMetrics.default.scaledFont(for: font)
        }()
        contentLabel.text = content.textValue
        qrCodeView.setContent(
            content.qrCodeValue,
            dimension: qrCodeDimensionConstraint.constant
        )
        iconView.setIcon(token: token, chain: token.chain)
        supportedTokensLabel.text = supporting
        
        let diff = actions.count - actionButtons.count
        if diff > 0 {
            for _ in 0..<diff {
                let button = UIButton(type: .system)
                button.configuration = {
                    var config: UIButton.Configuration = .plain()
                    config.imagePlacement = .top
                    config.imagePadding = 8
                    config.titleTextAttributesTransformer = .init { incoming in
                        var outgoing = incoming
                        outgoing.foregroundColor = R.color.text_secondary()
                        outgoing.font = UIFontMetrics.default.scaledFont(
                            for: .systemFont(ofSize: 12, weight: .medium)
                        )
                        return outgoing
                    }
                    return config
                }()
                button.addTarget(self, action: #selector(sendAction(_:)), for: .touchUpInside)
                actionStackView.addArrangedSubview(button)
                actionButtons.append(button)
            }
        } else if diff < 0 {
            for button in actionButtons.suffix(-diff) {
                button.isHidden = true
            }
        }
        
        for (index, button) in actionButtons.prefix(actions.count).enumerated() {
            let action = actions[index]
            if var config = button.configuration {
                switch action {
                case .copy:
                    config.image = R.image.address_action_copy()
                    config.title = R.string.localizable.copy()
                case .setAmount:
                    config.image = R.image.address_action_set_amount()
                    config.title = R.string.localizable.set_amount()
                case .share:
                    config.image = R.image.address_action_share()
                    config.title = R.string.localizable.share()
                }
                button.configuration = config
            }
            button.isHidden = false
            button.tag = index
        }
        self.actions = actions
    }
    
    @objc private func sendAction(_ sender: UIButton) {
        let action = actions[sender.tag]
        delegate?.depositEntryCell(self, didRequestAction: action)
    }
    
}
