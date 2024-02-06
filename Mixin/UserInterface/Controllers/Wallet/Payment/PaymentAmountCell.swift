import UIKit

final class PaymentAmountCell: UITableViewCell {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var tokenAmountLabel: UILabel!
    @IBOutlet weak var fiatMoneyAmountLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        stackView.setCustomSpacing(8, after: captionLabel)
        tokenAmountLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), 
                                 adjustForContentSize: true)
    }
    
}
