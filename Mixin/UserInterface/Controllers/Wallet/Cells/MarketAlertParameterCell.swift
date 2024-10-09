import UIKit

final class MarketAlertParameterCell: UITableViewCell {
    
    @IBOutlet weak var contentBackgroundView: UIView!
    @IBOutlet weak var iconImageView: MarketColorTintedImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var checkmarkImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentBackgroundView.layer.cornerRadius = 8
        contentBackgroundView.layer.masksToBounds = true
        contentBackgroundView.layer.borderColor = UIColor(displayP3RgbValue: 0x4B7CDD).cgColor
        contentBackgroundView.layer.borderWidth = 0
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        checkmarkImageView.isHidden = !selected
        contentBackgroundView.layer.borderWidth = selected ? 1 : 0
    }
    
}
