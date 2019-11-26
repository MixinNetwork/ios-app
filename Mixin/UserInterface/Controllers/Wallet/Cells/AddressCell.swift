import UIKit

class AddressCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    
    func render(address: Address, asset: AssetItem) {
        nameLabel.text = address.label
        addressLabel.text = address.fullAddress
    }
    
}
