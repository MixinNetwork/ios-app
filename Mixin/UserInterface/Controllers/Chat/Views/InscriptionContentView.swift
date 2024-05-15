import UIKit

final class InscriptionContentView: UIView {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sequenceLabel: UILabel!
    @IBOutlet weak var hashView: InscriptionHashView!
    @IBOutlet weak var iconView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        imageView.layer.cornerRadius = 5
        imageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        imageView.layer.masksToBounds = true
        iconView.mask = UIImageView(image: R.image.collection_token_mask())
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        iconView.mask?.frame = iconView.bounds
    }
    
    func prepareForReuse() {
        imageView.sd_cancelCurrentImageLoad()
        iconView.sd_cancelCurrentImageLoad()
    }
    
}
