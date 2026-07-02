import UIKit

final class BuyTokenMethodCell: UITableViewCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var apyLabel: InsetLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        apyLabel.contentInset = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        apyLabel.layer.cornerRadius = 4
        apyLabel.layer.masksToBounds = true
    }
    
}
