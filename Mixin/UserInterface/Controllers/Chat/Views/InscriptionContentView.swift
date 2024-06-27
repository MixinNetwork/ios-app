import UIKit
import MixinServices

final class InscriptionContentView: UIView {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sequenceLabel: UILabel!
    @IBOutlet weak var hashView: InscriptionHashView!
    @IBOutlet weak var iconView: UIImageView!
    
    private weak var textContentView: TextInscriptionContentView?
    
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
    
    func reloadData(with inscription: InscriptionItem?) {
        if let inscription {
            switch inscription.inscriptionContent {
            case let .image(url):
                imageView.contentMode = .scaleAspectFill
                imageView.sd_setImage(with: url)
                textContentView?.isHidden = true
            case let .text(collectionIconURL, textContentURL):
                imageView.contentMode = .scaleToFill
                imageView.image = R.image.collectible_text_background()
                let textContentView: TextInscriptionContentView
                if let view = self.textContentView {
                    view.isHidden = false
                    textContentView = view
                } else {
                    textContentView = TextInscriptionContentView(iconDimension: 40, spacing: 4)
                    textContentView.label.numberOfLines = 2
                    textContentView.label.font = .systemFont(ofSize: 10, weight: .semibold)
                    self.textContentView = textContentView
                    addSubview(textContentView)
                    textContentView.snp.makeConstraints { make in
                        make.top.equalTo(imageView).offset(25)
                        make.leading.equalTo(imageView).offset(10)
                        make.trailing.equalTo(imageView).offset(-10)
                    }
                }
                textContentView.reloadData(collectionIconURL: collectionIconURL,
                                           textContentURL: textContentURL)
            case .none:
                imageView.contentMode = .center
                imageView.image = R.image.inscription_intaglio()
                textContentView?.isHidden = true
            }
            nameLabel.text = inscription.collectionName
            sequenceLabel.text = inscription.sequenceRepresentation
            hashView.content = inscription.inscriptionHash
            iconView.sd_setImage(with: URL(string: inscription.collectionIconURL))
            iconView.alpha = 1
        } else {
            imageView.contentMode = .center
            textContentView?.isHidden = true
            nameLabel.text = ""
            sequenceLabel.text = ""
            hashView.content = nil
            iconView.alpha = 0
        }
    }
    
}
