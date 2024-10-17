import UIKit
import MixinServices

final class Web3DappCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var hostLabel: UILabel!
    
    override func prepareForReuse() {
        iconImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
    }
    
    func load(dapp: Web3Dapp) {
        iconImageView.sd_setImage(with: dapp.iconURL)
        nameLabel.text = dapp.name
        hostLabel.text = dapp.host
    }
    
}
