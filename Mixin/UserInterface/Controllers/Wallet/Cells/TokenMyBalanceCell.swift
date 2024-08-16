import UIKit

final class TokenMyBalanceCell: UITableViewCell {
    
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var periodLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var changeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        balanceLabel.setFont(scaledFor: .systemFont(ofSize: 18, weight: .medium), adjustForContentSize: true)
        periodLabel.setFont(scaledFor: .systemFont(ofSize: 12), adjustForContentSize: true)
        valueLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        changeLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
    }
    
}
