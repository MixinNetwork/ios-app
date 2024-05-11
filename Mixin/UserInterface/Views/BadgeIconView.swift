import UIKit
import MixinServices

final class BadgeIconView: UIView {
    
    private enum Corner {
        case round
        case radius(CGFloat)
    }
    
    @IBInspectable var badgeIconDiameter: CGFloat = 10
    @IBInspectable var badgeOutlineWidth: CGFloat = 2
    
    private let iconImageView = UIImageView()
    private let badgeBackgroundView = SolidBackgroundColoredView()
    private let badgeImageView = UIImageView()
    
    private var corner: Corner = .round {
        didSet {
            setNeedsLayout()
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
        case .radius(let radius):
            iconImageView.layer.cornerRadius = radius
        }
        let chainBackgroundDiameter = badgeIconDiameter + badgeOutlineWidth
        badgeBackgroundView.frame = CGRect(x: 0,
                                           y: bounds.height - chainBackgroundDiameter,
                                           width: chainBackgroundDiameter,
                                           height: chainBackgroundDiameter)
        badgeBackgroundView.layer.cornerRadius = chainBackgroundDiameter / 2
        badgeImageView.bounds = CGRect(x: 0, y: 0, width: badgeIconDiameter, height: badgeIconDiameter)
        badgeImageView.center = badgeBackgroundView.center
        badgeImageView.layer.cornerRadius = badgeImageView.bounds.width / 2
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
    }
    
    func setIcon(content: InscriptionContent) {
        isBadgeHidden = true
        corner = .radius(12)
        iconImageView.backgroundColor = .secondaryBackground
        if let url = content.inscriptionImageContentURL {
            iconImageView.sd_setImage(with: url)
        } else {
            iconImageView.image = R.image.inscription_intaglio()
        }
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
    }
    
    func setIcon(token: TokenItem) {
        iconImageView.sd_setImage(with: URL(string: token.iconURL),
                                  placeholderImage: nil,
                                  context: assetIconContext)
        if let str = token.chain?.iconUrl, let url = URL(string: str) {
            badgeImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
            isBadgeHidden = false
        } else {
            isBadgeHidden = true
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
        layer.shadowColor = R.color.icon_shadow()!.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 6
        iconImageView.backgroundColor = R.color.background_secondary()
        badgeImageView.backgroundColor = R.color.background_secondary()
    }
    
}
