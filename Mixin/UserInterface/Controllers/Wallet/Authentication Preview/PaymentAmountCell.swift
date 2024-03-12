import UIKit

final class PaymentAmountCell: UITableViewCell {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var primaryAmountLabel: UILabel!
    @IBOutlet weak var secondaryAmountLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        stackView.setCustomSpacing(8, after: captionLabel)
    }
    
    func setPrimaryAmountLabel(usesBoldFont: Bool) {
        let weight: UIFont.Weight = usesBoldFont ? .medium : .regular
        primaryAmountLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: weight),
                                   adjustForContentSize: true)
    }
    
}
