import UIKit
import MixinServices

final class SelectedTokenCell: SelectedItemCell<PlainTokenIconView> {
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.sd_cancelCurrentImageLoad()
        iconView.image = nil
    }
    
    func load(address: AddressItem) {
        if let string = address.tokenIconURL, let url = URL(string: string) {
            iconView.sd_setImage(with: url,
                                 placeholderImage: nil,
                                 context: assetIconContext)
        } else {
            iconView.image = R.image.unknown_session()
        }
        nameLabel.text = address.label
    }
    
    func load(token: TokenItem) {
        iconView.setIcon(token: token)
        nameLabel.text = token.symbol
    }
    
}
