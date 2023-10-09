import UIKit

final class PaymentSourceCell: UITableViewCell {
    
    @IBOutlet weak var schemeImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        schemeImageView.image = nil
        nameLabel.text = nil
    }
    
}
