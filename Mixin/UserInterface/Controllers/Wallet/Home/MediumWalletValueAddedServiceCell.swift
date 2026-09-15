import UIKit
import MixinServices

final class MediumWalletValueAddedServiceCell: UICollectionViewCell {
    
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var apyLabel: MarketColoredLabel!
    
    private weak var tokensViewIfLoaded: StackedTokenIconView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
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

extension MediumWalletValueAddedServiceCell: WalletValueAddedServiceCell {
    
    func load(account: CashAccount?) {
        titleLabel.text = R.string.localizable.cash_balance()
        tokensViewIfLoaded?.isHidden = true
        if let account {
            amountLabel.text = account.decimalBalance.formatted(balanceFormatStyle)
            apyLabel.text = account.displayAPY
            apyLabel.alpha = 1
        } else {
            amountLabel.text = "-"
            apyLabel.text = "-"
            apyLabel.alpha = 0
        }
    }
    
    func load(account: EarnAccount?) {
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
            amountLabel.text = account.usdBalance.formatted(balanceFormatStyle)
            tokensView.setIcons(urls: account.iconURLs)
        } else {
            amountLabel.text = "-"
            tokensView.setIcons(urls: [])
        }
        if let apy = account?.maxAPY {
            apyLabel.text = R.string.localizable.up_to_apy(apy)
            apyLabel.alpha = 1
        } else {
            apyLabel.text = "-"
            apyLabel.alpha = 0
        }
    }
    
}
