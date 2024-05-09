import UIKit

final class CollectibleCell: UICollectionViewCell {
    
    @IBOutlet weak var contentImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor(displayP3RgbValue: 0xe5e8ee).cgColor
    }
    
    override func prepareForReuse() {
        contentImageView.sd_cancelCurrentImageLoad()
        contentImageView.image = R.image.inscription_Intaglio()
        contentImageView.contentMode = .center
    }
    
}
