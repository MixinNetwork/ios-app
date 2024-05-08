import UIKit
import MixinServices

final class AssetIconView: UIView {
    
    @IBInspectable var chainIconWidth: CGFloat = 10
    @IBInspectable var chainIconOutlineWidth: CGFloat = 2
    
    let iconImageView = UIImageView()
    let chainBackgroundView = SolidBackgroundColoredView()
    let chainImageView = UIImageView()
    let shadowOffset: CGFloat = 5
    
    var isChainIconHidden = false {
        didSet {
            chainBackgroundView.isHidden = isChainIconHidden
            chainImageView.isHidden = isChainIconHidden
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
        iconImageView.layer.cornerRadius = iconImageView.bounds.width / 2
        let chainBackgroundDiameter = chainIconWidth + chainIconOutlineWidth
        chainBackgroundView.frame = CGRect(x: 0,
                                           y: bounds.height - chainBackgroundDiameter,
                                           width: chainBackgroundDiameter,
                                           height: chainBackgroundDiameter)
        chainBackgroundView.layer.cornerRadius = chainBackgroundDiameter / 2
        chainImageView.bounds = CGRect(x: 0, y: 0, width: chainIconWidth, height: chainIconWidth)
        chainImageView.center = chainBackgroundView.center
        chainImageView.layer.cornerRadius = chainImageView.bounds.width / 2
    }
    
    func prepareForReuse() {
        iconImageView.sd_cancelCurrentImageLoad()
        chainImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
        chainImageView.image = nil
    }
    
    func setIcon(web3Transaction transaction: Web3Transaction) {
        switch Web3Transaction.TransactionType(rawValue: transaction.operationType) {
        case .send:
            iconImageView.image = R.image.wallet.snapshot_withdrawal()
            isChainIconHidden = true
        case .receive:
            iconImageView.image = R.image.wallet.snapshot_deposit()
            isChainIconHidden = true
        default:
            isChainIconHidden = false
            if let app = transaction.appMetadata {
                iconImageView.sd_setImage(with: URL(string: app.iconURL))
                chainImageView.sd_setImage(with: URL(string: transaction.fee.iconURL))
            } else {
                iconImageView.image = nil
                chainImageView.image = nil
            }
        }
    }
    
    func setIcon(asset: AssetItem) {
        let url = URL(string: asset.iconUrl)
        iconImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
        if let str = asset.chain?.iconUrl, let url = URL(string: str) {
            chainImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
            isChainIconHidden = false
        } else {
            isChainIconHidden = true
        }
    }
    
    func setIcon(token: TokenItem) {
        iconImageView.sd_setImage(with: URL(string: token.iconURL),
                                  placeholderImage: nil,
                                  context: assetIconContext)
        if let str = token.chain?.iconUrl, let url = URL(string: str) {
            chainImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
            isChainIconHidden = false
        } else {
            isChainIconHidden = true
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
            chainImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
            isChainIconHidden = false
        } else {
            isChainIconHidden = true
        }
    }
    
    private func prepare() {
        backgroundColor = .clear
        chainBackgroundView.backgroundColorIgnoringSystemSettings = .background
        iconImageView.layer.masksToBounds = true
        chainBackgroundView.layer.masksToBounds = true
        chainImageView.layer.masksToBounds = true
        addSubview(iconImageView)
        addSubview(chainBackgroundView)
        addSubview(chainImageView)
        layer.shadowColor = R.color.icon_shadow()!.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 6
        iconImageView.backgroundColor = R.color.background_secondary()
        chainImageView.backgroundColor = R.color.background_secondary()
    }
    
}
