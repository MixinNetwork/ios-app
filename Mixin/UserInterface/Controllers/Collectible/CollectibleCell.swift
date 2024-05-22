import UIKit
import MixinServices

final class CollectibleCell: UICollectionViewCell {
    
    @IBOutlet weak var contentImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private let outlineColor = R.color.collectible_outline()!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = outlineColor.cgColor
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        contentImageView.sd_cancelCurrentImageLoad()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            contentView.layer.borderColor = outlineColor.resolvedColor(with: traitCollection).cgColor
        }
    }
    
    func render(item: InscriptionOutput) {
        if let url = item.inscription?.inscriptionImageContentURL {
            contentImageView.contentMode = .scaleAspectFill
            contentImageView.sd_setImage(with: url)
        } else {
            contentImageView.image = R.image.inscription_intaglio()
            contentImageView.contentMode = .center
        }
        if let inscription = item.inscription {
            titleLabel.text = inscription.collectionName
            subtitleLabel.text = inscription.sequenceRepresentation
        } else {
            titleLabel.text = ""
            subtitleLabel.text = ""
        }
    }
    
}
