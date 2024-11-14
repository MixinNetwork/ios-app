import UIKit
import MixinServices

final class PaymentCollectibleCell: UITableViewCell {
    
    @IBOutlet weak var contentImageWrapperView: UIView!
    @IBOutlet weak var contentImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private weak var textContentView: TextInscriptionContentView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentImageWrapperView.layer.cornerRadius = 12
        contentImageWrapperView.layer.masksToBounds = true
    }
    
    func load(item: InscriptionOutput) {
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
                textContentView = TextInscriptionContentView(iconDimension: 22, spacing: 2)
                textContentView.label.numberOfLines = 1
                textContentView.label.font = .systemFont(ofSize: 6, weight: .semibold)
                self.textContentView = textContentView
                contentImageWrapperView.addSubview(textContentView)
                textContentView.snp.makeConstraints { make in
                    let insets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
                    make.edges.equalToSuperview().inset(insets)
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
    
}
