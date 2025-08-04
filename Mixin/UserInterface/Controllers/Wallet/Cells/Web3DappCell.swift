import UIKit
import MixinServices

final class Web3DappCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var hostLabel: UILabel!
    
    @IBOutlet weak var iconDimensionConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        iconImageView.layer.cornerRadius = iconDimensionConstraint.constant / 2
        iconImageView.layer.masksToBounds = true
    }
    
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
