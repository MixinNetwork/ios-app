import UIKit

final class PaymentFeeCell: UITableViewCell {

    @IBOutlet weak var labelStackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var tokenAmountLabel: UILabel!
    @IBOutlet weak var fiatMoneyAmountLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        tokenAmountLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium),
                                 adjustForContentSize: true)
    }
    
}
