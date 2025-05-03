import UIKit
import MixinServices

final class Web3AmountChangeCell: UITableViewCell {
    
    enum Content {
        case unlimited
        case limited(token: String, fiatMoney: String?)
        case decodingFailed
    }
    
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
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assetIconView.prepareForReuse()
    }
    
    func reloadData(
        caption: String,
        content: Content,
        token: (any Token)?,
        chain: Chain?
    ) {
        switch content {
        case .unlimited:
            tokenAmountLabel.isHidden = true
            symbolLabel.text = R.string.localizable.approval_unlimited()
            if let symbol = token?.symbol {
                symbolLabel.text?.append(" " + symbol)
            }
            symbolLabel.setFont(
                scaledFor: .systemFont(ofSize: 20, weight: .medium),
                adjustForContentSize: true
            )
            symbolLabel.textColor = R.color.red()
            fiatMoneyValueLabel.text = R.string.localizable.approval_unlimited_warning(token?.symbol ?? "")
            fiatMoneyValueLabel.textColor = R.color.red()
            assetIconView.isHidden = false
            assetIconView.setIcon(token: token, chain: chain)
        case let .limited(tokenAmount, fiatMoneyAmount):
            tokenAmountLabel.text = tokenAmount
            tokenAmountLabel.isHidden = false
            symbolLabel.text = token?.symbol
            symbolLabel.setFont(
                scaledFor: .systemFont(ofSize: 12, weight: .medium),
                adjustForContentSize: true
            )
            symbolLabel.textColor = R.color.text()
            fiatMoneyValueLabel.text = fiatMoneyAmount
            fiatMoneyValueLabel.textColor = R.color.text_tertiary()
            assetIconView.isHidden = false
            assetIconView.setIcon(token: token, chain: chain)
        case .decodingFailed:
            tokenAmountLabel.isHidden = true
            symbolLabel.text = R.string.localizable.unable_to_estimate_asset_changes()
            symbolLabel.setFont(
                scaledFor: .systemFont(ofSize: 16, weight: .regular),
                adjustForContentSize: true
            )
            symbolLabel.textColor = R.color.red()
            fiatMoneyValueLabel.text = nil
            assetIconView.isHidden = true
        }
    }
    
}
