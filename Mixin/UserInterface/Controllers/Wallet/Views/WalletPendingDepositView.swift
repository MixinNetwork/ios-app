import UIKit
import MixinServices

final class WalletPendingDepositView: UIView {
    
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconStackView: UIStackView!
    @IBOutlet weak var label: UILabel!
    
    private let maxIconCount = 3
    
    override func awakeFromNib() {
        super.awakeFromNib()
        button.layer.masksToBounds = true
        button.layer.cornerRadius = 18
    }
    
    func reload(tokens: [MixinToken], snapshots: [SafeSnapshot]) {
        for iconView in iconStackView.arrangedSubviews {
            iconView.removeFromSuperview()
        }
        let iconViewCount = if tokens.count <= maxIconCount {
            tokens.count
        } else {
            maxIconCount - 1
        }
        var iconViews: [UIView] = tokens.prefix(iconViewCount).map { token in
            let view = StackedIconWrapperView<PlainTokenIconView>()
            view.backgroundColor = .clear
            iconStackView.addArrangedSubview(view)
            view.iconView.setIcon(token: token)
            return view
        }
        if tokens.count > maxIconCount {
            let view = StackedIconWrapperView<UILabel>()
            view.backgroundColor = .clear
            iconStackView.addArrangedSubview(view)
            view.iconView.backgroundColor = R.color.background_tag()
            view.iconView.textColor = R.color.text_tertiary()
            view.iconView.font = .systemFont(ofSize: 8)
            view.iconView.textAlignment = .center
            view.iconView.minimumScaleFactor = 0.1
            view.iconView.text = "+\(tokens.count - iconViewCount)"
            view.iconView.layer.cornerRadius = 7
            view.iconView.layer.masksToBounds = true
            iconViews.append(view)
        }
        for i in 0..<iconViews.count {
            let iconView = iconViews[i]
            let multiplier = i == iconViews.count - 1 ? 1 : 0.5
            iconView.snp.makeConstraints { make in
                make.width.equalTo(iconView.snp.height)
                    .multipliedBy(multiplier)
            }
        }
        if snapshots.count == 1,
           let amount = Decimal(string: snapshots[0].amount, locale: .enUSPOSIX),
           let token = tokens.first(where: { $0.assetID == snapshots[0].assetID })
        {
            let item = CurrencyFormatter.localizedString(
                from: amount,
                format: .precision,
                sign: .never,
                symbol: .custom(token.symbol)
            )
            label.text = R.string.localizable.deposit_pending_confirmation(item)
        } else {
            label.text = R.string.localizable.deposits_pending_confirmation(snapshots.count)
        }
    }
    
    func reload(pendingTransactions transactions: [Web3Transaction]) {
        label.text = if transactions.count == 1 {
            R.string.localizable.pending_transaction_one()
        } else {
            R.string.localizable.pending_transactions_count(transactions.count)
        }
    }
    
}
