import UIKit
import MixinServices

class AddressCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    func render(address: Address, asset: AssetItem) {
        nameLabel.text = address.label
        addressLabel.text = address.fullRepresentation
        dateLabel.text = address.updatedAt.toUTCDate().timeAgo()
    }
    
    func render(address: Address, asset: MixinTokenItem) {
        nameLabel.text = address.label
        addressLabel.text = address.fullRepresentation
        dateLabel.text = address.updatedAt.toUTCDate().timeAgo()
    }
    
}
