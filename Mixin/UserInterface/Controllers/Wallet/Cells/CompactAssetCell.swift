import UIKit
import MixinServices

class CompactAssetCell: UITableViewCell {
    
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assetIconView.prepareForReuse()
    }
    
    func render(asset: AssetItem) {
        assetIconView.setIcon(asset: asset)
        titleLabel.text = asset.symbol
        subtitleLabel.text = asset.name
    }
    
}
