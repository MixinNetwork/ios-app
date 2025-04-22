import UIKit
import MixinServices

final class Web3AmountChangeCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var tokenStackView: UIStackView!
    @IBOutlet weak var tokenAmountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var assetIconView: BadgeIconView!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        symbolLabel.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 5, right: 0)
        contentStackView.setCustomSpacing(1, after: tokenStackView)
    }
    
    func reloadData(token: Web3Token, tokenAmount: String?, fiatMoneyAmount: String?) {
        assetIconView.setIcon(web3Token: token)
        
        if let tokenAmount {
            tokenAmountLabel.text = tokenAmount
            tokenAmountLabel.isHidden = false
            symbolLabel.text = token.symbol
            symbolLabel.setFont(
                scaledFor: .systemFont(ofSize: 12, weight: .medium),
                adjustForContentSize: true
            )
            symbolLabel.textColor = R.color.text()
        } else {
            tokenAmountLabel.isHidden = true
            symbolLabel.text = R.string.localizable.approval_unlimited() + " " + token.symbol
            symbolLabel.setFont(
                scaledFor: .systemFont(ofSize: 20, weight: .medium),
                adjustForContentSize: true
            )
            symbolLabel.textColor = R.color.red()
        }
        
        if let fiatMoneyAmount {
            fiatMoneyValueLabel.text = fiatMoneyAmount
            fiatMoneyValueLabel.textColor = R.color.text_tertiary()
        } else {
            fiatMoneyValueLabel.text = R.string.localizable.approval_unlimited_warning(token.symbol)
            fiatMoneyValueLabel.textColor = R.color.red()
        }
    }
    
}
