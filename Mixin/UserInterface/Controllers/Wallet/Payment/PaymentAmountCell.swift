import UIKit

final class PaymentAmountCell: UITableViewCell {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var secondaryAmountLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        stackView.setCustomSpacing(8, after: captionLabel)
        amountLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), 
                            adjustForContentSize: true)
    }
    
}
