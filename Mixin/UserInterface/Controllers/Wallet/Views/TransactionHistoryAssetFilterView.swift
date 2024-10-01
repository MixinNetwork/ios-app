import UIKit
import MixinServices

final class TransactionHistoryAssetFilterView: TransactionHistoryFilterView {
    
    private let maxIconCount = 10
    private let iconsStackView = UIStackView()
    
    func reloadData(tokens: [Token]) {
        for view in iconsStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        let iconViews = tokens.prefix(maxIconCount).map { token in
            let view = IconWrapperView<PlainTokenIconView>()
            view.backgroundColor = .clear
            iconsStackView.addArrangedSubview(view)
            view.iconView.setIcon(token: token)
            return view
        }
        for i in 0..<iconViews.count {
            let iconView = iconViews[i]
            let multiplier = i == iconViews.count - 1 ? 1 : 0.5
            iconView.snp.makeConstraints { make in
                make.width.equalTo(iconView.snp.height)
                    .multipliedBy(multiplier)
            }
        }
        switch tokens.count {
        case 0:
            label.text = R.string.localizable.assets()
        case 1:
            label.text = tokens[0].symbol
        default:
            label.text = R.string.localizable.number_of_assets(tokens.count)
        }
    }
    
    func reloadData(coins: [MarketAlertCoin]) {
        for view in iconsStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        let iconViews = coins.prefix(maxIconCount).map { coin in
            let view = IconWrapperView<PlainTokenIconView>()
            view.backgroundColor = .clear
            iconsStackView.addArrangedSubview(view)
            view.iconView.setIcon(coin: coin)
            return view
        }
        for i in 0..<iconViews.count {
            let iconView = iconViews[i]
            let multiplier = i == iconViews.count - 1 ? 1 : 0.5
            iconView.snp.makeConstraints { make in
                make.width.equalTo(iconView.snp.height)
                    .multipliedBy(multiplier)
            }
        }
        switch coins.count {
        case 0:
            label.text = R.string.localizable.assets()
        case 1:
            label.text = coins[0].symbol
        default:
            label.text = R.string.localizable.number_of_assets(coins.count)
        }
    }
    
    override func loadSubviews() {
        super.loadSubviews()
        label.text = R.string.localizable.assets()
        iconsStackView.axis = .horizontal
        iconsStackView.spacing = 0
        contentStackView.insertArrangedSubview(iconsStackView, at: 0)
        iconsStackView.snp.makeConstraints { make in
            make.height.equalTo(20)
        }
    }
    
}
