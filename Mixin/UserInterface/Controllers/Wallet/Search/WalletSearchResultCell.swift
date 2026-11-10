import UIKit
import MixinServices

final class WalletSearchResultCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: BadgeIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var leverageLabel: LeverageLabel!
    @IBOutlet weak var apyLabel: InsetLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        subtitleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        leverageLabel.setFont(scaledFor: .condensed(size: 12), adjustForContentSize: true)
        apyLabel.setFont(scaledFor: .systemFont(ofSize: 12, weight: .medium), adjustForContentSize: true)
        apyLabel.contentInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
        apyLabel.layer.cornerRadius = 4
        apyLabel.layer.masksToBounds = true
        apyLabel.textColor = R.color.market_green()
        apyLabel.backgroundColor = R.color.market_green()!.withAlphaComponent(0.1)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        leverageLabel.text = nil
        leverageLabel.isHidden = true
        apyLabel.text = nil
        apyLabel.isHidden = true
        accessibilityLabel = nil
    }
    
    func load<Token>(result: WalletSearchItem<Token>) where Token: ValuableToken & OnChainToken {
        iconView.prepareForReuse()
        leverageLabel.isHidden = true
        apyLabel.isHidden = true
        switch result {
        case .token(let token):
            iconView.setIcon(token: token, chain: token.chain)
            titleLabel.text = token.localizedBalanceWithSymbol
            subtitleLabel.text = token.name
        case let .perps(position, market):
            iconView.setIcon(market: market)
            let isLong = position.side == PerpetualOrderSide.long.rawValue
            titleLabel.text = if isLong {
                R.string.localizable.long_asset(position.tokenSymbol)
            } else {
                R.string.localizable.short_asset(position.tokenSymbol)
            }
            subtitleLabel.text = CurrencyFormatter.localizedString(
                from: Decimal(string: position.quantity, locale: .enUSPOSIX) ?? 0,
                format: .precision,
                sign: .never,
                symbol: .custom(position.tokenSymbol),
            )
            leverageLabel.text = PerpetualLeverage.stringRepresentation(multiplier: position.leverage)
            leverageLabel.color = isLong ? .long : .short
            leverageLabel.isHidden = false
        case let .earn(product, token):
            iconView.setIcon(token: token)
            titleLabel.text = token.symbol
            let principal = Decimal(string: product.account.totalPrincipal, locale: .enUSPOSIX) ?? 0
            let earnings = Decimal(string: product.account.redeemableEarnings, locale: .enUSPOSIX) ?? 0
            subtitleLabel.text = CurrencyFormatter.localizedString(
                from: principal + earnings,
                format: .precision,
                sign: .never,
                symbol: .custom(token.symbol),
            )
            if let rate = product.annualRates.compactMap({ Decimal(string: $0, locale: .enUSPOSIX) }).max() {
                let percentage = PercentageFormatter.string(from: rate, format: .pretty, sign: .never)
                apyLabel.text = R.string.localizable.cash_account_apy(percentage)
                apyLabel.isHidden = false
            }
        case .collectible(let output):
            if let inscription = output.inscription {
                iconView.setIcon(content: inscription)
            }
            titleLabel.text = output.inscription?.collectionName ?? R.string.localizable.collectibles()
            subtitleLabel.text = output.inscription?.sequenceRepresentation ?? output.inscriptionHash
        }
        accessibilityLabel = [
            titleLabel.text,
            leverageLabel.isHidden ? nil : leverageLabel.text,
            apyLabel.isHidden ? nil : apyLabel.text,
            subtitleLabel.text,
        ].compactMap { $0 }.joined(separator: ", ")
    }
    
}
