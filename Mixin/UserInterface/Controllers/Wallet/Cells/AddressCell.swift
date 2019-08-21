import UIKit

class AddressCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    
    func render(address: Address, asset: AssetItem) {
        if asset.isAccount {
            nameLabel.text = address.accountName
            addressLabel.text = address.accountTag
        } else {
            nameLabel.text = address.label
            addressLabel.text = address.publicKey
        }
    }
    
}
