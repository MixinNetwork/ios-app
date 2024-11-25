import UIKit
import MixinServices

final class CollectibleCell: UICollectionViewCell {
    
    @IBOutlet weak var contentImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private let outlineColor = R.color.outline_primary()!
    
    private weak var textContentView: TextInscriptionContentView?
    
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
        textContentView?.prepareForReuse()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            contentView.layer.borderColor = outlineColor.resolvedColor(with: traitCollection).cgColor
        }
    }
    
    func render(item: InscriptionOutput) {
        switch item.inscription?.inscriptionContent {
        case let .image(url):
            contentImageView.contentMode = .scaleAspectFill
            contentImageView.sd_setImage(with: url)
            textContentView?.isHidden = true
        case let .text(collectionIconURL, textContentURL):
            contentImageView.contentMode = .scaleToFill
            contentImageView.image = R.image.collectible_text_background()
            let textContentView: TextInscriptionContentView
            if let view = self.textContentView {
                view.isHidden = false
                textContentView = view
            } else {
                textContentView = TextInscriptionContentView(iconDimension: 50, spacing: 4)
                textContentView.label.numberOfLines = 2
                textContentView.label.font = .systemFont(ofSize: 14, weight: .semibold)
                self.textContentView = textContentView
                contentView.addSubview(textContentView)
                
                let topGuide = UILayoutGuide()
                contentView.addLayoutGuide(topGuide)
                topGuide.snp.makeConstraints { make in
                    make.top.leading.trailing.equalTo(contentImageView)
                    make.height.equalTo(contentImageView).multipliedBy(37.0 / 160.0)
                }
                
                textContentView.snp.makeConstraints { make in
                    make.top.equalTo(topGuide.snp.bottom)
                    make.leading.equalTo(contentImageView).offset(24)
                    make.trailing.equalTo(contentImageView).offset(-24)
                    make.bottom.lessThanOrEqualTo(contentImageView)
                }
            }
            textContentView.reloadData(collectionIconURL: collectionIconURL,
                                       textContentURL: textContentURL)
        case .none:
            contentImageView.contentMode = .center
            contentImageView.image = R.image.inscription_intaglio()
            textContentView?.isHidden = true
        }
        if let inscription = item.inscription {
            titleLabel.text = inscription.collectionName
            subtitleLabel.text = inscription.sequenceRepresentation
        } else {
            titleLabel.text = ""
            subtitleLabel.text = ""
        }
    }
    
    func render(collection: InscriptionCollectionPreview) {
        if let url = URL(string: collection.iconURL) {
            contentImageView.contentMode = .scaleAspectFill
            contentImageView.sd_setImage(with: url)
        } else {
            contentImageView.image = R.image.inscription_intaglio()
            contentImageView.contentMode = .center
        }
        textContentView?.isHidden = true
        titleLabel.text = collection.name
        subtitleLabel.text = "\(collection.inscriptionCount)"
    }
    
}
