import UIKit

class SearchAssetCell: UITableViewCell {
    
    @IBOutlet weak var assetIconImageView: UIImageView!
    @IBOutlet weak var chainIconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var selectedImageView: UIImageView!
    @IBOutlet weak var deselectedImageView: UIImageView!
    @IBOutlet weak var forceSelectedImageView: UIImageView!
    
    private var forceSelected = false
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if forceSelected {
            selectedImageView.isHidden = true
            deselectedImageView.isHidden = true
            forceSelectedImageView.isHidden = false
        } else {
            selectedImageView.isHidden = !selected
            deselectedImageView.isHidden = selected
            forceSelectedImageView.isHidden = true
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        forceSelected = false
        assetIconImageView.sd_cancelCurrentImageLoad()
        chainIconImageView.sd_cancelCurrentImageLoad()
    }
    
    func render(asset: AssetItem, forceSelected: Bool) {
        assetIconImageView.sd_setImage(with: URL(string: asset.iconUrl), completed: nil)
        chainIconImageView.sd_setImage(with: URL(string: asset.chainIconUrl ?? ""), completed: nil)
        titleLabel.text = asset.symbol
        subtitleLabel.text = asset.name
        self.forceSelected = forceSelected
    }
    
}
