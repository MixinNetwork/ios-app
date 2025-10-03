import UIKit
import MixinServices

final class DepositLinkView: UIView, XibDesignable {
    
    enum Size {
        case large
        case medium
        case small
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var qrCodeDimensionConstraint: NSLayoutConstraint!
    
    weak var contentView: UIStackView!
    weak var iconBackgroundView: UIView!
    weak var iconView: UIView?
    weak var footerView: UIView?
    
    weak var iconBackgroundDimensionConstraint: NSLayoutConstraint!
    
    // By changing this property only, labels are not updated
    // Request layout by update `size` and call `load(link:) to apply the effect
    var adjustsFontForContentSizeCategory = true
    
    var size: Size = .medium {
        didSet {
            switch size {
            case .large:
                contentView.setCustomSpacing(12, after: titleLabel)
                titleLabel.font = font(ofSize: 20, weight: .semibold)
                qrCodeDimensionConstraint.constant = 200
            case .medium:
                contentView.setCustomSpacing(8, after: titleLabel)
                titleLabel.font = font(ofSize: 18, weight: .semibold)
                qrCodeDimensionConstraint.constant = 180
            case .small:
                contentView.setCustomSpacing(4, after: titleLabel)
                titleLabel.font = font(ofSize: 18, weight: .semibold)
                qrCodeDimensionConstraint.constant = 160
            }
            subtitleLabel.font = font(ofSize: 14)
            iconBackgroundDimensionConstraint.constant = iconBackgroundDimension
            iconBackgroundView.layer.cornerRadius = iconBackgroundDimension / 2
        }
    }
    
    private var iconBackgroundDimension: CGFloat {
        switch size {
        case .large:
            48
        case .medium:
            44
        case .small:
            40
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSubviews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    func load(link: DepositLink) {
        qrCodeView.setContent(
            link.qrCodeValue,
            dimension: qrCodeDimensionConstraint.constant,
            activityIndicator: false
        )
        footerView?.removeFromSuperview()
        switch link.chain {
        case .mixin(let context):
            qrCodeView.setDefaultCornerCurve()
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
                        .font: font(ofSize: 14),
                        .foregroundColor: R.color.text_tertiary()!,
                        .paragraphStyle: style,
                    ]
                )
                if let range = text.string.range(of: transferring, options: [.backwards]) {
                    text.addAttributes(
                        [
                            .font: font(ofSize: 14, weight: .medium),
                            .foregroundColor: R.color.text()!,
                        ],
                        range: NSRange(range, in: text.string)
                    )
                }
                footerLabel.attributedText = text
            } else {
                load(icon: .receiveMoneyAvatar(context.account))
                footerLabel.textAlignment = .center
                footerLabel.font = font(ofSize: 14)
                footerLabel.textColor = R.color.text_tertiary()
                footerLabel.text = R.string.localizable.transfer_qrcode_prompt()
            }
            footerLabel.numberOfLines = 0
            contentView.addArrangedSubview(footerLabel)
            self.footerView = footerLabel
        case .native(let context):
            switch context.token.chainID {
            case ChainID.lightning:
                qrCodeView.setContinuousCornerCurve(radius: 6)
            default:
                qrCodeView.setDefaultCornerCurve()
            }
            
            let token = context.token
            let address = context.address
            
            titleLabel.text = R.string.localizable.deposit_token_to_mixin(token.symbol)
            subtitleLabel.text = R.string.localizable.scan_qr_code_to_send_token(token.symbol)
            load(icon: .token(token))
            
            let footerStackView = UIStackView()
            footerStackView.axis = .vertical
            footerStackView.spacing = switch size {
            case .large, .medium:
                12
            case .small:
                8
            }
            func makeTitleLabel() -> UILabel {
                let label = UILabel()
                label.font = switch size {
                case .large, .medium:
                    font(ofSize: 14)
                case .small:
                    font(ofSize: 12)
                }
                label.textColor = R.color.text_quaternary()
                return label
            }
            
            func makeContentLabel() -> UILabel {
                let label = UILabel()
                label.font = switch size {
                case .large, .medium:
                    font(ofSize: 16)
                case .small:
                    font(ofSize: 14)
                }
                label.textColor = R.color.text()
                return label
            }
            
            let addressTitleLabel = makeTitleLabel()
            addressTitleLabel.text = switch context.token.chainID {
            case ChainID.lightning:
                R.string.localizable.deposit_invoice()
            default:
                R.string.localizable.address()
            }
            let addressContentLabel = makeContentLabel()
            addressContentLabel.attributedText = {
                let fontSize: CGFloat = switch size {
                case .large, .medium:
                    if address.count > 100 {
                        12
                    } else if address.count > 80 {
                        14
                    } else {
                        16
                    }
                case .small:
                    if address.count > 100 {
                        10
                    } else if address.count > 80 {
                        12
                    } else {
                        14
                    }
                }
                
                let text = NSMutableAttributedString(
                    string: address,
                    attributes: [
                        .font: font(ofSize: fontSize),
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
                        .font: font(ofSize: fontSize, weight: .medium),
                        .foregroundColor: R.color.text()!,
                    ]
                    for range in [prefixRange, suffixRange] {
                        text.setAttributes(attributes, range: range)
                    }
                }
                return text
            }()
            addressContentLabel.numberOfLines = 0
            addressContentLabel.lineBreakMode = .byCharWrapping
            let addressStackView = UIStackView(
                arrangedSubviews: [addressTitleLabel, addressContentLabel]
            )
            addressStackView.axis = .vertical
            addressStackView.spacing = 6
            footerStackView.addArrangedSubview(addressStackView)
            
            let infoStackView = UIStackView()
            
            if let network = token.depositNetworkName {
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
                    symbol: .custom(token.symbol)
                )
                infoStackView.addArrangedSubview(amountStackView)
            } else if let limitation = context.limitation {
                amountTitleLabel.text = R.string.localizable.minimum_deposit()
                amountValueLabel.text = limitation.minimumDescription(symbol: context.token.symbol)
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
    
    private func font(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        if adjustsFontForContentSizeCategory {
            return UIFontMetrics.default.scaledFont(for:
                    .systemFont(ofSize: size, weight: weight)
            )
        } else {
            let size = switch ScreenHeight.current {
            case .short:
                size * 0.6
            case .medium:
                size * 0.75
            default:
                size
            }
            return .systemFont(ofSize: round(size), weight: weight)
        }
    }
    
    private func load(icon: Icon) {
        iconView?.removeFromSuperview()
        
        func addIconView(_ iconView: UIView) {
            iconView.overrideUserInterfaceStyle = .light
            addSubview(iconView)
            iconView.snp.makeConstraints { make in
                let insets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
                make.edges.equalTo(iconBackgroundView).inset(insets)
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
        let iconBackgroundView = UIView()
        iconBackgroundView.backgroundColor = .white
        iconBackgroundView.layer.masksToBounds = true
        addSubview(iconBackgroundView)
        iconBackgroundView.snp.makeConstraints { make in
            make.center.equalTo(qrCodeView)
            make.width.equalTo(iconBackgroundView.snp.height)
        }
        self.iconBackgroundView = iconBackgroundView
        self.iconBackgroundDimensionConstraint = iconBackgroundView.heightAnchor
            .constraint(equalToConstant: iconBackgroundDimension)
        self.iconBackgroundDimensionConstraint.isActive = true
    }
    
}
