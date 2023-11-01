import UIKit
import MixinServices

class CompactAssetCell: UITableViewCell {
    
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var changeLabel: InsetLabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var noValueIndicator: UILabel!
    @IBOutlet weak var chainTagLabel: InsetLabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        chainTagLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assetIconView.prepareForReuse()
    }
    
    func render(asset: TokenItem) {
        assetIconView.setIcon(token: asset)
        nameLabel.text = asset.symbol
        descriptionLabel.text = asset.name
        if let tag = asset.chainTag {
            chainTagLabel.text = tag
            chainTagLabel.isHidden = false
        } else {
            chainTagLabel.isHidden = true
        }
        if asset.decimalUSDPrice > 0 {
            changeLabel.text = " \(asset.localizedUsdChange)%"
            if asset.decimalUSDChange > 0 {
                changeLabel.textColor = .walletGreen
            } else {
                changeLabel.textColor = .walletRed
            }
            priceLabel.text = Currency.current.symbol + asset.localizedFiatMoneyPrice
            changeLabel.isHidden = false
            priceLabel.isHidden = false
            noValueIndicator.isHidden = true
        } else {
            changeLabel.text = R.string.localizable.na() // Just for layout guidance
            priceLabel.text = nil
            changeLabel.isHidden = true
            priceLabel.isHidden = true
            noValueIndicator.isHidden = false
        }
    }
    
}
