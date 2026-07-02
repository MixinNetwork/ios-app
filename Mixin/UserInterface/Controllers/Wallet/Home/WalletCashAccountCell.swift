import UIKit
import MixinServices

final class WalletCashAccountCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var apyLabel: MarketColoredLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        balanceLabel.setFont(
            scaledFor: .systemFont(ofSize: 18, weight: .semibold),
            adjustForContentSize: true
        )
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 12, weight: .medium),
            adjustForContentSize: true
        )
        apyLabel.marketColor = .rising
    }
    
    func load(account: CashAccount?) {
        titleLabel.text = R.string.localizable.cash_balance()
        if let account {
            balanceLabel.text = account.displayBalance
            apyLabel.text = account.displayAPY
        } else {
            balanceLabel.text = "-"
            apyLabel.text = ""
        }
        symbolLabel.text = Currency.current.code
    }
    
}
