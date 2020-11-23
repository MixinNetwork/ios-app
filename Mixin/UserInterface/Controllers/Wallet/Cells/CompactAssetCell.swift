import UIKit
import MixinServices

class CompactAssetCell: UITableViewCell {
    
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var changeLabel: InsetLabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var noValueIndicator: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assetIconView.prepareForReuse()
    }
    
    func render(asset: AssetItem) {
        assetIconView.setIcon(asset: asset)
        nameLabel.text = asset.symbol
        descriptionLabel.text = asset.name
        
        // TODO: Update these after decimal calculation is merged
        if asset.priceUsd.doubleValue > 0 {
            changeLabel.text = " \(asset.localizedUsdChange)%"
            if asset.changeUsd.doubleValue > 0 {
                changeLabel.textColor = .walletGreen
            } else {
                changeLabel.textColor = .walletRed
            }
            priceLabel.text = Currency.current.symbol + asset.localizedFiatMoneyPrice
            changeLabel.isHidden = false
            priceLabel.isHidden = false
            noValueIndicator.isHidden = true
        } else {
            changeLabel.text = Localized.WALLET_NO_PRICE // Just for layout guidance
            priceLabel.text = nil
            changeLabel.isHidden = true
            priceLabel.isHidden = true
            noValueIndicator.isHidden = false
        }
    }
    
}
