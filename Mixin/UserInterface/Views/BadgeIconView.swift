import UIKit
import MixinServices

final class BadgeIconView: UIView {
    
    private enum Corner: Equatable {
        case round
        case radius(CGFloat)
        case hexagon
    }
    
    @IBInspectable var badgeIconDiameter: CGFloat = 13
    @IBInspectable var badgeOutlineWidth: CGFloat = 1.5
    
    private let iconImageView = UIImageView()
    private let badgeBackgroundView = SolidBackgroundColoredView()
    private let badgeImageView = UIImageView()
    
    private var corner: Corner = .round {
        didSet {
            if corner != oldValue {
                setNeedsLayout()
            }
        }
    }
    
    private var isBadgeHidden = false {
        didSet {
            badgeBackgroundView.isHidden = isBadgeHidden
            badgeImageView.isHidden = isBadgeHidden
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        iconImageView.frame = bounds
        switch corner {
        case .round:
            iconImageView.layer.cornerRadius = iconImageView.bounds.width / 2
            iconImageView.mask = nil
        case .radius(let radius):
            iconImageView.layer.cornerRadius = radius
            iconImageView.mask = nil
        case .hexagon:
            iconImageView.layer.cornerRadius = 0
            let iconMask: UIView
            if let mask = iconImageView.mask {
                iconMask = mask
            } else {
                let mask = UIImageView(image: R.image.collection_token_mask())
                mask.contentMode = .scaleAspectFit
                iconImageView.mask = mask
                iconMask = mask
            }
            iconMask.frame = iconImageView.bounds
        }
        if !isBadgeHidden {
            let R = bounds.height / 2
            let r = badgeIconDiameter / 2
            let x = max(0, round(0.29289322 * R - r))
            badgeImageView.frame = CGRect(
                x: x,
                y: bounds.height - x - badgeIconDiameter,
                width: badgeIconDiameter,
                height: badgeIconDiameter
            )
            badgeImageView.layer.cornerRadius = badgeImageView.bounds.width / 2
            badgeBackgroundView.frame = badgeImageView.frame
                .insetBy(dx: -badgeOutlineWidth, dy: -badgeOutlineWidth)
            badgeBackgroundView.layer.cornerRadius = badgeBackgroundView.bounds.width / 2
        }
    }
    
    func prepareForReuse() {
        iconImageView.sd_cancelCurrentImageLoad()
        badgeImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
        badgeImageView.image = nil
    }
    
    func setIcon(web3Transaction transaction: Web3Transaction) {
        switch Web3Transaction.TransactionType(rawValue: transaction.operationType) {
        case .send:
            iconImageView.image = R.image.wallet.snapshot_withdrawal()
            isBadgeHidden = true
        case .receive:
            iconImageView.image = R.image.wallet.snapshot_deposit()
            isBadgeHidden = true
        default:
            isBadgeHidden = false
            if let app = transaction.appMetadata {
                iconImageView.sd_setImage(with: URL(string: app.iconURL))
                badgeImageView.sd_setImage(with: URL(string: transaction.fee.iconURL))
            } else {
                iconImageView.image = nil
                badgeImageView.image = nil
            }
        }
        corner = .round
    }
    
    func setIcon(content: InscriptionContentProvider) {
        isBadgeHidden = true
        iconImageView.backgroundColor = .secondaryBackground
        switch content.inscriptionContent {
        case .image(let url):
            iconImageView.sd_setImage(with: url)
        case .text:
            iconImageView.image = R.image.collectible_text_background()
        case .none:
            iconImageView.image = R.image.inscription_intaglio()
        }
        corner = .radius(12)
    }
    
    func setIcon(asset: AssetItem) {
        let url = URL(string: asset.iconUrl)
        iconImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
        if let str = asset.chain?.iconUrl, let url = URL(string: str) {
            badgeImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
            isBadgeHidden = false
        } else {
            isBadgeHidden = true
        }
        corner = .round
    }
    
    func setIcon(token: TokenItem) {
        iconImageView.sd_setImage(with: URL(string: token.iconURL),
                                  placeholderImage: nil,
                                  context: assetIconContext)
        if token.collectionHash == nil {
            if let chainIcon = token.chain?.iconUrl, let url = URL(string: chainIcon) {
                badgeImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
                isBadgeHidden = false
            } else {
                isBadgeHidden = true
            }
            corner = .round
        } else {
            isBadgeHidden = true
            corner = .hexagon
        }
    }
    
    func setIcon(web3Token token: Web3Token) {
        if let url = URL(string: token.iconURL) {
            iconImageView.sd_setImage(with: url,
                                      placeholderImage: nil,
                                      context: assetIconContext)
        } else {
            iconImageView.image = R.image.unknown_session()
        }
        if let url = URL(string: token.chainIconURL) {
            badgeImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
            isBadgeHidden = false
        } else {
            isBadgeHidden = true
        }
        corner = .round
    }
    
    func setIcon(swappableToken token: SwapToken) {
        if let url = token.iconURL {
            iconImageView.sd_setImage(with: url,
                                      placeholderImage: nil,
                                      context: assetIconContext)
        } else {
            iconImageView.image = R.image.unknown_session()
        }
        if let url = token.chain.iconURL {
            badgeImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
            isBadgeHidden = false
        } else {
            isBadgeHidden = true
        }
        corner = .round
    }
    
    func setIcon(coin: MarketAlertCoin) {
        if let url = URL(string: coin.iconURL) {
            iconImageView.sd_setImage(with: url,
                                      placeholderImage: nil,
                                      context: assetIconContext)
        } else {
            iconImageView.image = R.image.unknown_session()
        }
        isBadgeHidden = true
        corner = .round
    }
    
    func setIcon(address: AddressItem) {
        if let string = address.tokenIconURL, let url = URL(string: string) {
            iconImageView.sd_setImage(with: url,
                                      placeholderImage: nil,
                                      context: assetIconContext)
        } else {
            iconImageView.image = R.image.unknown_session()
        }
        if let string = address.tokenChainIconURL, let url = URL(string: string) {
            badgeImageView.sd_setImage(with: url,
                                       placeholderImage: nil,
                                       context: assetIconContext)
            isBadgeHidden = false
        } else {
            isBadgeHidden = true
        }
        corner = .round
    }
    
    private func prepare() {
        backgroundColor = .clear
        badgeBackgroundView.backgroundColorIgnoringSystemSettings = .background
        iconImageView.layer.masksToBounds = true
        badgeBackgroundView.layer.masksToBounds = true
        badgeImageView.layer.masksToBounds = true
        addSubview(iconImageView)
        addSubview(badgeBackgroundView)
        addSubview(badgeImageView)
        iconImageView.backgroundColor = R.color.background_secondary()
        badgeImageView.backgroundColor = R.color.background_secondary()
    }
    
}
