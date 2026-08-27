import UIKit
import MixinServices

final class LargeWalletValueAddedServiceCell: UICollectionViewCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var subtitleStackView: UIStackView!
    
    private weak var apyLabelIfLoaded: MarketColoredLabel?
    private weak var tokensViewIfLoaded: StackedTokenIconView?
    
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
    }
    
}

extension LargeWalletValueAddedServiceCell: WalletValueAddedServiceCell {
    
    func load(account: CashAccount?) {
        iconImageView.image = R.image.cash()
        titleLabel.text = R.string.localizable.cash_balance()
        tokensViewIfLoaded?.isHidden = true
        let apyLabel: MarketColoredLabel
        if let label = apyLabelIfLoaded {
            apyLabel = label
        } else {
            apyLabel = MarketColoredLabel()
            subtitleStackView.addArrangedSubview(apyLabel)
            self.apyLabelIfLoaded = apyLabel
        }
        apyLabel.isHidden = false
        apyLabel.marketColor = .rising
        if let account {
            balanceLabel.text = account.decimalBalance.formatted(balanceFormatStyle)
            apyLabel.text = account.displayAPY
        } else {
            balanceLabel.text = "-"
            apyLabel.text = ""
        }
        symbolLabel.text = Currency.usd.code
    }
    
    func load(account: EarnAccount?) {
        iconImageView.image = R.image.earn()
        titleLabel.text = R.string.localizable.earn_balance()
        apyLabelIfLoaded?.isHidden = true
        let tokensView: StackedTokenIconView
        if let view = tokensViewIfLoaded {
            tokensView = view
        } else {
            tokensView = StackedTokenIconView()
            tokensView.size = .small
            subtitleStackView.addArrangedSubview(tokensView)
            tokensView.snp.makeConstraints { make in
                make.height.equalTo(18)
            }
            self.tokensViewIfLoaded = tokensView
        }
        tokensView.isHidden = false
        if let account {
            balanceLabel.text = account.usdBalance.formatted(balanceFormatStyle)
            tokensView.setIcons(urls: account.iconURLs)
        } else {
            balanceLabel.text = "-"
            tokensView.setIcons(urls: [])
        }
        symbolLabel.text = Currency.usd.code
    }
    
}
