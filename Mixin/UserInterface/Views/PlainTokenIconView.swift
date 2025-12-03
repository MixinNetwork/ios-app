import UIKit
import MixinServices

final class PlainTokenIconView: UIImageView {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        layer.masksToBounds = true
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.masksToBounds = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
    }
    
    func setIcon(urlString: String) {
        sd_setImage(
            with: URL(string: urlString),
            placeholderImage: nil,
            context: assetIconContext
        )
    }
    
    func setIcon(tokenIconURL url: URL?) {
        sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
    }
    
    func setIcon(token: (any Token)?) {
        if let iconURL = token?.iconURL, let url = URL(string: iconURL) {
            setIcon(tokenIconURL: url)
        } else {
            image = R.image.unknown_session()
        }
    }
    
    func setIcon(address: AddressItem) {
        if let string = address.tokenChainIconURL, let url = URL(string: string) {
            setIcon(tokenIconURL: url)
        } else {
            image = R.image.unknown_session()
        }
    }
    
    func setIcon(market: Market) {
        if let url = URL(string: market.iconURL) {
            setIcon(tokenIconURL: url)
        } else {
            image = R.image.unknown_session()
        }
    }
    
    func setIcon(coin: MarketAlertCoin) {
        if let url = URL(string: coin.iconURL) {
            setIcon(tokenIconURL: url)
        } else {
            image = R.image.unknown_session()
        }
    }
    
    func prepareForReuse() {
        sd_cancelCurrentImageLoad()
    }
    
}
