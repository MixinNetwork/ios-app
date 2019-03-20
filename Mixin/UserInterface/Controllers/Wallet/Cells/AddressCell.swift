import UIKit

class AddressCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView.createSelectedBackgroundView()
    }
    
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
