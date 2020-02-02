import UIKit
import MixinServices

class SearchAssetCell: UITableViewCell {
    
    @IBOutlet weak var checkmarkView: CheckmarkView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private var forceSelected = false
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if forceSelected {
            checkmarkView.status = .forceSelected
        } else {
            checkmarkView.status = selected ? .selected : .unselected
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        forceSelected = false
        assetIconView.prepareForReuse()
    }
    
    func render(asset: AssetItem, forceSelected: Bool) {
        assetIconView.setIcon(asset: asset)
        titleLabel.text = asset.symbol
        subtitleLabel.text = asset.name
        self.forceSelected = forceSelected
    }
    
}
