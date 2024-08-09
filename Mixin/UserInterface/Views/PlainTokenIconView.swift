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
    
    func setIcon(token: Token) {
        sd_setImage(with: URL(string: token.iconURL),
                    placeholderImage: nil,
                    context: assetIconContext)
    }
    
    func setIcon(web3Token token: Web3Token) {
        if let url = URL(string: token.iconURL) {
            sd_setImage(with: url,
                        placeholderImage: nil,
                        context: assetIconContext)
        } else {
            image = R.image.unknown_session()
        }
    }
    
    func setIcon(token: SwappableToken) {
        if let url = token.iconURL {
            sd_setImage(with: url,
                        placeholderImage: nil,
                        context: assetIconContext)
        } else {
            image = R.image.unknown_session()
        }
    }
    
    func setIcon(address: AddressItem) {
        if let string = address.tokenIconURL, let url = URL(string: string) {
            sd_setImage(with: url,
                        placeholderImage: nil,
                        context: assetIconContext)
        } else {
            image = R.image.unknown_session()
        }
    }
    
    func prepareForReuse() {
        sd_cancelCurrentImageLoad()
    }
    
}
