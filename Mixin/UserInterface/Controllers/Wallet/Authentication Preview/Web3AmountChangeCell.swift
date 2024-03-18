import UIKit
import MixinServices

final class Web3AmountChangeCell: UITableViewCell {
    
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var tokenAmountLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    
    func setToken(_ token: TokenItem, tokenAmount: String?, fiatMoneyAmount: String?) {
        assetIconView.setIcon(token: token)
        
        if let tokenAmount {
            tokenAmountLabel.text = tokenAmount
            symbolLabel.text = token.symbol
            symbolLabel.setFont(scaledFor: .systemFont(ofSize: 12, weight: .medium),
                                adjustForContentSize: true)
            symbolLabel.textColor = R.color.text()
        } else {
            tokenAmountLabel.text = nil
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
