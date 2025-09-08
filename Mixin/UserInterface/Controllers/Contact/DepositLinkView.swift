import UIKit
import MixinServices

final class DepositLinkView: UIView, XibDesignable {
    
    enum Size {
        case large
        case medium
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var qrCodeDimensionConstraint: NSLayoutConstraint!
    
    private let iconBackgroundDimension: CGFloat = 48
    private let iconDimension: CGFloat = 44
    
    private weak var contentView: UIStackView!
    private weak var iconBackgroundView: UIView!
    private weak var iconView: UIView?
    private weak var footerView: UIView?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSubviews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    func layout(size: Size) {
        switch size {
        case .large:
            contentView.setCustomSpacing(12, after: titleLabel)
            titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        case .medium:
            contentView.setCustomSpacing(8, after: titleLabel)
            titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        }
    }
    
    func load(link: DepositLink) {
        qrCodeView.setContent(
            link.value,
            dimension: qrCodeDimensionConstraint.constant,
            activityIndicator: false
        )
        footerView?.removeFromSuperview()
        switch link.chain {
        case .mixin(let context):
            titleLabel.text = context.account.fullName
            subtitleLabel.text = R.string.localizable.contact_mixin_id(
                context.account.identityNumber
            )
            let footerLabel = UILabel()
            if let spec = context.specification {
                load(icon: .token(spec.token))
                let transferring = CurrencyFormatter.localizedString(
                    from: spec.amount,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(spec.token.symbol)
                )
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                let text = NSMutableAttributedString(
                    string: R.string.localizable.scan_qr_code_to_transfer_on_mixin(transferring),
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 14),
                        .foregroundColor: R.color.text_tertiary()!,
                        .paragraphStyle: style,
                    ]
                )
                if let range = text.string.range(of: transferring, options: [.backwards]) {
                    text.addAttributes(
                        [
                            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                            .foregroundColor: R.color.text()!,
                        ],
                        range: NSRange(range, in: text.string)
                    )
                }
                footerLabel.attributedText = text
            } else {
                load(icon: .receiveMoneyAvatar(context.account))
                footerLabel.textAlignment = .center
                footerLabel.font = .systemFont(ofSize: 14)
                footerLabel.textColor = R.color.text_tertiary()
                footerLabel.text = R.string.localizable.transfer_qrcode_prompt()
            }
            contentView.addArrangedSubview(footerLabel)
            self.footerView = footerLabel
        case .native(let context):
            titleLabel.text = R.string.localizable.deposit_token_to_mixin(context.token.symbol)
            subtitleLabel.text = R.string.localizable.scan_qr_code_to_send_token(context.token.symbol)
            load(icon: .token(context.token))
            
            let footerStackView = UIStackView()
            footerStackView.axis = .vertical
            footerStackView.spacing = 16
            func makeTitleLabel() -> UILabel {
                let label = UILabel()
                label.font = .systemFont(ofSize: 12)
                label.textColor = R.color.text_quaternary()
                return label
            }
            
            func makeContentLabel() -> UILabel {
                let label = UILabel()
                label.font = .systemFont(ofSize: 14)
                label.textColor = R.color.text()
                return label
            }
            
            let address = context.address
            let addressTitleLabel = makeTitleLabel()
            addressTitleLabel.text = R.string.localizable.address()
            let addressContentLabel = makeContentLabel()
            addressContentLabel.attributedText = {
                let fontSize: CGFloat = if address.count > 100 {
                    10
                } else if address.count > 80 {
                    12
                } else {
                    14
                }
                let text = NSMutableAttributedString(
                    string: address,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: fontSize),
                        .foregroundColor: R.color.text_secondary()!,
                    ]
                )
                if address.count > 14 {
                    let prefixRange = NSRange(
                        address.startIndex..<address.index(address.startIndex, offsetBy: 8),
                        in: address
                    )
                    let suffixRange = NSRange(
                        address.index(address.endIndex, offsetBy: -6)..<address.endIndex,
                        in: address
                    )
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                        .foregroundColor: R.color.text()!,
                    ]
                    for range in [prefixRange, suffixRange] {
                        text.setAttributes(attributes, range: range)
                    }
                }
                return text
            }()
            addressContentLabel.numberOfLines = 0
            let addressStackView = UIStackView(
                arrangedSubviews: [addressTitleLabel, addressContentLabel]
            )
            addressStackView.axis = .vertical
            addressStackView.spacing = 6
            footerStackView.addArrangedSubview(addressStackView)
            
            let infoStackView = UIStackView()
            
            if let network = context.token.depositNetworkName {
                let networkTitleLabel = makeTitleLabel()
                networkTitleLabel.text = R.string.localizable.network()
                let networkContentLabel = makeContentLabel()
                networkContentLabel.text = network
                let networkStackView = UIStackView(
                    arrangedSubviews: [networkTitleLabel, networkContentLabel]
                )
                networkStackView.axis = .vertical
                networkStackView.spacing = 6
                infoStackView.addArrangedSubview(networkStackView)
            }
            
            let amountTitleLabel = makeTitleLabel()
            amountTitleLabel.textAlignment = .right
            let amountValueLabel = makeContentLabel()
            amountValueLabel.textAlignment = .right
            let amountStackView = UIStackView(
                arrangedSubviews: [amountTitleLabel, amountValueLabel]
            )
            amountStackView.axis = .vertical
            amountStackView.spacing = 6
            if let amount = context.amount {
                amountTitleLabel.text = R.string.localizable.amount()
                amountValueLabel.text = CurrencyFormatter.localizedString(
                    from: amount,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(context.token.symbol)
                )
                infoStackView.addArrangedSubview(amountStackView)
            } else if let minimumDeposit = context.minimumDeposit {
                amountTitleLabel.text = R.string.localizable.minimum_deposit()
                amountValueLabel.text = minimumDeposit
                infoStackView.addArrangedSubview(amountStackView)
            }
            
            if !infoStackView.arrangedSubviews.isEmpty {
                infoStackView.axis = .horizontal
                infoStackView.distribution = .equalSpacing
                footerStackView.addArrangedSubview(infoStackView)
            }
            
            contentView.addArrangedSubview(footerStackView)
            self.footerView = footerStackView
        }
    }
    
}

extension DepositLinkView {
    
    private enum Icon {
        case token(any Token)
        case receiveMoneyAvatar(Account)
    }
    
    private final class ReceiveMoneyAvatarView: AvatarImageView {
        
        let iconImageView = UIImageView(image: R.image.ic_receive_money())
        
        override func loadSubviews() {
            super.loadSubviews()
            addSubview(iconImageView)
            iconImageView.snp.makeConstraints { make in
                make.trailing.bottom.equalToSuperview()
            }
        }
        
    }
    
    private func load(icon: Icon) {
        iconView?.removeFromSuperview()
        
        func addIconView(_ iconView: UIView) {
            iconView.overrideUserInterfaceStyle = .light
            addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(44)
                make.center.equalTo(qrCodeView.snp.center)
            }
            self.iconView = iconView
        }
        
        switch icon {
        case .token(let item):
            let tokenView = BadgeIconView()
            addIconView(tokenView)
            tokenView.setIcon(
                token: item,
                chain: (item as? OnChainToken)?.chain
            )
        case .receiveMoneyAvatar(let account):
            let avatarView = ReceiveMoneyAvatarView()
            addIconView(avatarView)
            avatarView.setImage(with: account)
        }
    }
    
    private func loadSubviews() {
        contentView = loadXib() as? UIStackView
        contentView.setCustomSpacing(20, after: subtitleLabel)
        contentView.setCustomSpacing(16, after: qrCodeView)
        qrCodeView.setDefaultCornerCurve()
        let iconBackgroundView = UIView()
        iconBackgroundView.backgroundColor = .white
        iconBackgroundView.layer.cornerRadius = iconBackgroundDimension / 2
        iconBackgroundView.layer.masksToBounds = true
        addSubview(iconBackgroundView)
        iconBackgroundView.snp.makeConstraints { make in
            make.center.equalTo(qrCodeView)
            make.width.height.equalTo(iconBackgroundDimension)
        }
        self.iconBackgroundView = iconBackgroundView
    }
    
}
