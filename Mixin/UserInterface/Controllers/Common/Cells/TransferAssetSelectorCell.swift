import UIKit

class TransferAssetSelectorCell: UITableViewCell {
    
    @IBOutlet weak var iconView: ChainSubscriptedAssetIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func render(asset: AssetItem) {
        iconView.setIcon(asset: asset)
        symbolLabel.text = asset.symbol
        balanceLabel.text = asset.localizedBalance
    }
    
}
