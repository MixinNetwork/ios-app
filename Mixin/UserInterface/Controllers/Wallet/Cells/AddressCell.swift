import UIKit

class AddressCell: UITableViewCell {

    static let cellReuseId = "AddressCell"

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    
    func render(address: Address) {
        nameLabel.text = address.label
        addressLabel.text = address.publicKey
    }
    
}
