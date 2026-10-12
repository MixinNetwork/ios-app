import UIKit
import MixinServices

final class LargeWalletValueAddedServiceCell: UICollectionViewCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var apyLabel: MarketColoredLabel!
    
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
        apyLabel.setFont(
            scaledFor: .systemFont(ofSize: 12, weight: .medium),
            adjustForContentSize: true
        )
        apyLabel.contentInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
        apyLabel.layer.cornerRadius = 4
        apyLabel.layer.masksToBounds = true
        apyLabel.marketColor = .rising
        updateAPYLabelBackground()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateAPYLabelBackground),
            name: AppGroupUserDefaults.User.marketColorAppearanceDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func updateAPYLabelBackground() {
        apyLabel.backgroundColor = MarketColor.rising.uiColor.withAlphaComponent(0.1)
    }
    
}

extension LargeWalletValueAddedServiceCell: WalletValueAddedServiceCell {
    
    func load(account: CashAccount?) {
        iconImageView.image = R.image.cash()
        titleLabel.text = R.string.localizable.cash_balance()
        tokensViewIfLoaded?.isHidden = true
        apyLabel.isHidden = false
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
        let tokensView: StackedTokenIconView
        if let view = tokensViewIfLoaded {
            tokensView = view
        } else {
            tokensView = StackedTokenIconView()
            tokensView.size = .small
            titleStackView.addArrangedSubview(tokensView)
            tokensView.snp.makeConstraints { make in
                make.height.equalTo(18)
            }
            tokensView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            tokensView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
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
        if let apy = account?.maxAPY {
            apyLabel.text = R.string.localizable.up_to_apy(apy)
            apyLabel.isHidden = false
        } else {
            apyLabel.isHidden = true
        }
    }
    
}
