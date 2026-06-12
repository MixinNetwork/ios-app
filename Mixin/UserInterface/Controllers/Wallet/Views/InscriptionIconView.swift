import UIKit
import MixinServices

final class InscriptionIconView: UIView {
    
    var content: InscriptionContent? {
        didSet {
            switch content {
            case let .image(url):
                imageView.contentMode = .scaleAspectFill
                imageView.sd_setImage(with: url)
                textContentView?.isHidden = true
            case let .text(collectionIconURL, textContentURL):
                imageView.contentMode = .scaleToFill
                imageView.image = R.image.collectible_text_background()
                let contentView: TextInscriptionContentView
                if let view = self.textContentView {
                    view.isHidden = false
                    contentView = view
                } else {
                    contentView = TextInscriptionContentView(iconDimension: 22, spacing: 1)
                    contentView.label.numberOfLines = 1
                    contentView.label.font = .systemFont(ofSize: 6, weight: .semibold)
                    addSubview(contentView)
                    contentView.snp.makeConstraints { make in
                        let inset = UIEdgeInsets(top: 4, left: 6, bottom: 5, right: 6)
                        make.edges.equalToSuperview().inset(inset)
                    }
                    self.textContentView = contentView
                }
                contentView.reloadData(collectionIconURL: collectionIconURL,
                                       textContentURL: textContentURL)
            case .none:
                imageView.contentMode = .scaleAspectFit
                imageView.image = R.image.inscription_intaglio()
                textContentView?.isHidden = true
            }
        }
    }
    
    private let imageView = UIImageView()
    
    private weak var textContentView: TextInscriptionContentView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubview()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubview()
    }
    
    override func layoutSubviews() {
        if content == nil {
            imageView.frame.size = CGSize(width: bounds.width / 2, height: bounds.height / 2)
        } else {
            imageView.frame.size = CGSize(width: bounds.width, height: bounds.height)
        }
        imageView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    }
    
    func prepareForReuse() {
        imageView.sd_cancelCurrentImageLoad()
        textContentView?.prepareForReuse()
    }
    
    private func loadSubview() {
        backgroundColor = R.color.sticker_button_background_disabled()
        layer.cornerRadius = 12
        layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
    }
    
}
