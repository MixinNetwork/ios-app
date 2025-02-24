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
    
    func setIcon(tokenIconURL url: URL?) {
        sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
    }
    
    func setIcon(token: MixinToken) {
        setIcon(tokenIconURL: URL(string: token.iconURL))
    }
    
    func setIcon(web3Token token: Web3Token) {
        if let url = URL(string: token.iconURL) {
            setIcon(tokenIconURL: url)
        } else {
            image = R.image.unknown_session()
        }
    }
    
    func setIcon(token: SwapToken) {
        if let url = token.iconURL {
            setIcon(tokenIconURL: url)
        } else {
            image = R.image.unknown_session()
        }
    }
    
    func setIcon(address: AddressItem) {
        if let string = address.tokenIconURL, let url = URL(string: string) {
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
