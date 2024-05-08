import UIKit
import MixinServices

class AssetIconView: BadgeIconView {
    
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
            iconImageView.sd_setImage(with: URL(string: token.iconURL),
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
    
}
