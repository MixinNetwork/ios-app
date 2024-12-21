import UIKit
import MixinServices

final class TransactionHistoryOpponentFilterView: TransactionHistoryFilterView {
    
    private let iconsStackView = UIStackView()
    private let maxIconCount = 10
    
    func reloadData(users: [UserItem], addresses: [AddressItem]) {
        for view in iconsStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        let userIconViews = users.prefix(maxIconCount).map { user in
            let view = StackedIconWrapperView<AvatarImageView>()
            view.backgroundColor = .clear
            view.iconView.titleFontSize = 9
            view.iconView.setImage(with: user)
            iconsStackView.addArrangedSubview(view)
            return view
        }
        let addressIconViews = addresses.prefix(maxIconCount - userIconViews.count).map { address in
            let view = StackedIconWrapperView<PlainTokenIconView>()
            view.backgroundColor = .clear
            view.iconView.setIcon(address: address)
            iconsStackView.addArrangedSubview(view)
            return view
        }
        let iconViews = userIconViews + addressIconViews
        for i in 0..<iconViews.count {
            let iconView = iconViews[i]
            let multiplier = i == iconViews.count - 1 ? 1 : 0.5
            iconView.snp.makeConstraints { make in
                make.width.equalTo(iconView.snp.height)
                    .multipliedBy(multiplier)
            }
        }
        switch (users.count, addresses.count) {
        case (0, 0):
            label.text = R.string.localizable.opponents()
        case (1, 0):
            label.text = users[0].fullName
        case (0, 1):
            let full = addresses[0].fullRepresentation
            label.text = Address.truncatedRepresentation(string: full, prefixCount: 3, suffixCount: 3)
        default:
            label.text = R.string.localizable.number_of_opponents(users.count + addresses.count)
        }
    }
    
    override func loadSubviews() {
        super.loadSubviews()
        label.text = R.string.localizable.opponents()
        iconsStackView.axis = .horizontal
        iconsStackView.spacing = 0
        contentStackView.insertArrangedSubview(iconsStackView, at: 0)
        iconsStackView.snp.makeConstraints { make in
            make.height.equalTo(20)
        }
    }
    
}
