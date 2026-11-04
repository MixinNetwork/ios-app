import UIKit
import MixinServices

final class SelectedTokenCell: SelectedItemCell<PlainTokenIconView> {
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(address: AddressItem) {
        iconView.setIcon(address: address)
        nameLabel.text = address.label
    }
    
    func load(network: AddressBookNetwork) {
        if let chain = network.chain {
            iconView.setIcon(urlString: chain.iconUrl)
        } else {
            iconView.image = R.image.unknown_session()
        }
        nameLabel.text = network.name
    }
    
    func load(token: any Token) {
        iconView.setIcon(token: token)
        nameLabel.text = token.symbol
    }
    
    func load(coin: MarketAlertCoin) {
        iconView.setIcon(coin: coin)
        nameLabel.text = coin.symbol
    }
    
}
