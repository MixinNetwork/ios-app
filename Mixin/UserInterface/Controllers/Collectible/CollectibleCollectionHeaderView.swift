import UIKit
import MixinServices

final class CollectibleCollectionHeaderView: UICollectionReusableView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(8, after: tokenIconView)
        contentStackView.setCustomSpacing(4, after: nameLabel)
        contentStackView.setCustomSpacing(12, after: countLabel)
        tokenIconView.layer.shadowOpacity = 0
    }
    
    func load(token: TokenItem?, collection: InscriptionCollectionPreview) {
        if let token {
            tokenIconView.setIcon(token: token)
        }
        nameLabel.text = collection.name
        countLabel.text = R.string.localizable.collection_collected(collection.inscriptionCount)
        descriptionLabel.text = collection.description
    }
    
}
