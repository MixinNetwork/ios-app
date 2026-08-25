import UIKit
import MixinServices

final class TokenCell: UICollectionViewCell {
    
    static let symbolAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.scaledFont(ofSize: 12, weight: .medium),
        .foregroundColor: UIColor.text
    ]
    
    @IBOutlet weak var assetIconView: BadgeIconView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var maliciousWarningImageView: UIImageView!
    @IBOutlet weak var balanceLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    @IBOutlet weak var fiatMoneyPriceLabel: UILabel!
    @IBOutlet weak var fiatMoneyBalanceLabel: UILabel!
    @IBOutlet weak var noFiatMoneyPriceIndicatorLabel: UILabel!
    
    private let fiatMoneyBalanceAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 12)),
    ]
    
    private let earnSymbolAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 12, weight: .medium)
        ),
        .foregroundColor: R.color.theme()!,
    ]
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleStackView.setCustomSpacing(4, after: maliciousWarningImageView)
        balanceLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
        symbolLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 3, right: 0)
        changeLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 4, right: 0)
        balanceLabel.setFont(scaledFor: .condensed(size: 20), adjustForContentSize: true)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assetIconView.prepareForReuse()
    }
    
    func load(token: MixinTokenItem, availableForEarning: Bool) {
        assetIconView.setIcon(token: token)
        maliciousWarningImageView.isHidden = !token.isMalicious
        balanceLabel.text = if token.decimalBalance.isZero {
            zeroWith2Fractions
        } else {
            CurrencyFormatter.localizedString(
                from: token.decimalBalance,
                format: .precision,
                sign: .never
            )
        }
        symbolLabel.attributedText = NSAttributedString(
            string: token.symbol,
            attributes: TokenCell.symbolAttributes
        )
        if token.decimalUSDPrice > 0 {
            changeLabel.text = token.localizedUSDChange
            changeLabel.marketColor = .byValue(token.decimalUSDChange)
            changeLabel.alpha = 1
            fiatMoneyPriceLabel.text = token.localizedFiatMoneyPrice
            fiatMoneyPriceLabel.alpha = 1
            noFiatMoneyPriceIndicatorLabel.alpha = 0
        } else {
            changeLabel.text = R.string.localizable.na() // Just for layout guidance
            changeLabel.alpha = 0
            fiatMoneyPriceLabel.text = nil
            fiatMoneyPriceLabel.alpha = 0
            noFiatMoneyPriceIndicatorLabel.alpha = 1
        }
        if availableForEarning {
            let balance = NSMutableAttributedString(
                string: token.estimatedFiatMoneyBalance + " • ",
                attributes: fiatMoneyBalanceAttributes,
            )
            balance.append(
                NSAttributedString(
                    string: R.string.localizable.earn(),
                    attributes: earnSymbolAttributes
                )
            )
            fiatMoneyBalanceLabel.attributedText = balance
        } else {
            fiatMoneyBalanceLabel.attributedText = NSAttributedString(
                string: token.estimatedFiatMoneyBalance,
                attributes: fiatMoneyBalanceAttributes,
            )
        }
    }
    
    func load(web3Token token: Web3TokenItem) {
        assetIconView.setIcon(web3Token: token)
        maliciousWarningImageView.isHidden = !token.isMalicious
        balanceLabel.text = if token.decimalBalance.isZero {
            zeroWith2Fractions
        } else {
            CurrencyFormatter.localizedString(
                from: token.decimalBalance,
                format: .precision,
                sign: .never
            )
        }
        symbolLabel.attributedText = NSAttributedString(
            string: token.symbol,
            attributes: TokenCell.symbolAttributes
        )
        if token.decimalUSDPrice > 0 {
            changeLabel.text = token.localizedUSDChange
            changeLabel.marketColor = .byValue(token.decimalUSDChange)
            changeLabel.alpha = 1
            fiatMoneyPriceLabel.text = token.localizedFiatMoneyPrice
            fiatMoneyPriceLabel.alpha = 1
            noFiatMoneyPriceIndicatorLabel.alpha = 0
        } else {
            changeLabel.text = R.string.localizable.na() // Just for layout guidance
            changeLabel.alpha = 0
            fiatMoneyPriceLabel.text = nil
            fiatMoneyPriceLabel.alpha = 0
            noFiatMoneyPriceIndicatorLabel.alpha = 1
        }
        fiatMoneyBalanceLabel.text = token.estimatedFiatMoneyBalance
    }
    
}
