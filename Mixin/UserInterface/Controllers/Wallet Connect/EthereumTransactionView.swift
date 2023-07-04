import UIKit

final class EthereumTransactionView: UIStackView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setCustomSpacing(12, after: titleLabel)
    }
    
}
