import UIKit
import MixinServices

class TransferTypeCell: UITableViewCell {
    
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var checkmarkView: UIImageView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assetIconView.prepareForReuse()
    }
    
    func render(asset: AssetItem) {
        assetIconView.setIcon(asset: asset)
        nameLabel.text = asset.name
        let balance = CurrencyFormatter.localizedString(from: asset.balance, format: .precision, sign: .never)
            ?? asset.localizedBalance
        balanceLabel.text = balance + " " + asset.symbol
    }
    
}
