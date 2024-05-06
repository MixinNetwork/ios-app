import UIKit
import MixinServices

final class Web3AmountChangeCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var tokenStackView: UIStackView!
    @IBOutlet weak var tokenAmountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        symbolLabel.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 5, right: 0)
        contentStackView.setCustomSpacing(1, after: tokenStackView)
    }
    
    func setToken(_ token: Web3TransferableToken, tokenAmount: String?, fiatMoneyAmount: String?) {
        switch token {
        case let token as TokenItem:
            assetIconView.setIcon(token: token)
        case let token as Web3Token:
            assetIconView.setIcon(web3Token: token)
        default:
            assertionFailure()
        }
        
        if let tokenAmount {
            tokenAmountLabel.text = tokenAmount
            tokenAmountLabel.isHidden = false
            symbolLabel.text = token.symbol
            symbolLabel.setFont(scaledFor: .systemFont(ofSize: 12, weight: .medium),
                                adjustForContentSize: true)
            symbolLabel.textColor = R.color.text()
        } else {
            tokenAmountLabel.isHidden = true
            symbolLabel.text = "Unlimited " + token.symbol
            symbolLabel.setFont(scaledFor: .systemFont(ofSize: 20, weight: .medium),
                                adjustForContentSize: true)
            symbolLabel.textColor = R.color.red()
        }
        
        if let fiatMoneyAmount {
            fiatMoneyValueLabel.text = fiatMoneyAmount
            fiatMoneyValueLabel.textColor = R.color.text_tertiary()
        } else {
            fiatMoneyValueLabel.text = "This dapp can withdraw all your \(token.symbol)."
            fiatMoneyValueLabel.textColor = R.color.red()
        }
    }
    
}
