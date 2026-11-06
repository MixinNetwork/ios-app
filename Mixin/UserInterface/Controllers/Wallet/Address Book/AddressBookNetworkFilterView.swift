import UIKit
import MixinServices

final class AddressBookNetworkFilterView: TransactionHistoryFilterView {
    
    private let maxIconCount = 10
    private let iconsStackView = UIStackView()
    
    func reloadData(networks: [AddressBookNetwork]) {
        for view in iconsStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        let iconViews = networks.prefix(maxIconCount).map { network in
            let view = StackedIconWrapperView<PlainTokenIconView>()
            view.backgroundColor = .clear
            iconsStackView.addArrangedSubview(view)
            if let chain = network.chain {
                view.iconView.setIcon(urlString: chain.iconUrl)
            }
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
        switch networks.count {
        case 0:
            label.text = R.string.localizable.all_networks()
        case 1:
            label.text = networks[0].name
        default:
            label.text = R.string.localizable.number_of_networks(networks.count)
        }
    }
    
    override func loadSubviews() {
        super.loadSubviews()
        backgroundColor = R.color.background()
        label.text = R.string.localizable.all_networks()
        iconsStackView.axis = .horizontal
        iconsStackView.spacing = 0
        contentStackView.insertArrangedSubview(iconsStackView, at: 0)
        iconsStackView.snp.makeConstraints { make in
            make.height.equalTo(20)
        }
    }
    
}
