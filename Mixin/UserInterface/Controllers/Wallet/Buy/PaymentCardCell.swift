import UIKit

final class PaymentCardCell: UITableViewCell {

    @IBOutlet weak var schemeImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        schemeImageView.image = nil
        titleLabel.text = nil
    }
    
}
