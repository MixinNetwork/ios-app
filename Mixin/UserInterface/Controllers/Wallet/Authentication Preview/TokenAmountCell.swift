import UIKit

final class TokenAmountCell: UITableViewCell {
    
    @IBOutlet weak var labelStackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var secondaryAmountLabel: UILabel!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        amountLabel.setFont(scaledFor: .systemFont(ofSize: 16),
                            adjustForContentSize: true)
    }
    
}
