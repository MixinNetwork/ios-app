import UIKit

final class Web3DappCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var hostLabel: UILabel!
    
    override func prepareForReuse() {
        iconImageView.sd_cancelCurrentImageLoad()
        iconImageView.image = nil
    }
    
}
