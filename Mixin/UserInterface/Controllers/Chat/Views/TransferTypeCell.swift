import UIKit

class TransferTypeCell: UITableViewCell {
    
    @IBOutlet weak var checkmarkView: CheckmarkView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assetIconView.prepareForReuse()
    }
    
    func render(asset: AssetItem) {
        assetIconView.setIcon(asset: asset)
        symbolLabel.text = asset.symbol
        balanceLabel.text = asset.localizedBalance + " " + Localized.TRANSFER_BALANCE
    }
    
}
