import UIKit
import MixinServices

class AddressCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    func render(address: Address, asset: AssetItem) {
        nameLabel.text = address.label
        addressLabel.text = address.fullAddress
        dateLabel.text = address.updatedAt.toUTCDate().timeAgo()
    }
    
}
