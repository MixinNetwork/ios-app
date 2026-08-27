import UIKit
import MixinServices

final class MediumWalletValueAddedServiceCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var descriptionStackView: UIStackView!
    
    private weak var apyLabelIfLoaded: MarketColoredLabel?
    private weak var tokensViewIfLoaded: StackedTokenIconView?
    
    private var formatStyle: Decimal.FormatStyle.Currency {
        Decimal.FormatStyle.Currency
            .currency(code: "USD")
            .presentation(.narrow)
            .precision(.fractionLength(0...2))
            .rounded(rule: .towardZero)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        amountLabel.setFont(
            scaledFor: .systemFont(ofSize: 18, weight: .semibold),
            adjustForContentSize: true
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateAPYLabelBackground),
            name: AppGroupUserDefaults.User.marketColorAppearanceDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func updateAPYLabelBackground() {
        apyLabelIfLoaded?.backgroundColor = MarketColor.rising.uiColor.withAlphaComponent(0.1)
    }
    
}

extension MediumWalletValueAddedServiceCell: WalletValueAddedServiceCell {
    
    func load(account: CashAccount?) {
        titleLabel.text = R.string.localizable.cash_balance()
        tokensViewIfLoaded?.isHidden = true
        let apyLabel: MarketColoredLabel
        if let label = apyLabelIfLoaded {
            apyLabel = label
        } else {
            apyLabel = MarketColoredLabel()
            apyLabel.setFont(
                scaledFor: .systemFont(ofSize: 12, weight: .medium),
                adjustForContentSize: true
            )
            apyLabel.contentInset = UIEdgeInsets(top: 3, left: 1, bottom: 3, right: 1)
            descriptionStackView.insertArrangedSubview(apyLabel, at: 0)
            apyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            apyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            apyLabel.layer.cornerRadius = 4
            apyLabel.layer.masksToBounds = true
            self.apyLabelIfLoaded = apyLabel
        }
        apyLabel.isHidden = false
        apyLabel.marketColor = .rising
        updateAPYLabelBackground()
        if let account {
            amountLabel.text = account.decimalBalance.formatted(formatStyle)
            apyLabel.text = account.displayAPY
        } else {
            amountLabel.text = "-"
            apyLabel.text = ""
        }
    }
    
    func load(account: EarnAccount?) {
        titleLabel.text = R.string.localizable.earn_balance()
        apyLabelIfLoaded?.isHidden = true
        let tokensView: StackedTokenIconView
        if let view = tokensViewIfLoaded {
            tokensView = view
        } else {
            tokensView = StackedTokenIconView()
            tokensView.size = .small
            descriptionStackView.insertArrangedSubview(tokensView, at: 0)
            tokensView.snp.makeConstraints { make in
                make.height.equalTo(18)
            }
            tokensView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            tokensView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            self.tokensViewIfLoaded = tokensView
        }
        tokensView.isHidden = false
        if let account {
            amountLabel.text = account.usdBalance.formatted(formatStyle)
            tokensView.setIcons(urls: account.iconURLs)
        } else {
            amountLabel.text = "-"
            tokensView.setIcons(urls: [])
        }
    }
    
}
