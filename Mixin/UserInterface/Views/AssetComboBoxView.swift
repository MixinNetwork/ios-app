import UIKit
import MixinServices

class AssetComboBoxView: ComboBoxView {
    
    let iconView = BadgeIconView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        insertIconView(iconView)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        insertIconView(iconView)
    }
    
    func load(asset: AssetItem) {
        titleLabel.text = asset.name
        let balance = CurrencyFormatter.localizedString(from: asset.balance, format: .precision, sign: .never) ?? asset.localizedBalance
        subtitleLabel.text = balance + " " + asset.symbol
        iconView.prepareForReuse()
        iconView.setIcon(asset: asset)
    }
    
}
