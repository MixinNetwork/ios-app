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
                    self.textContentView = contentView
                }
                contentView.reloadData(collectionIconURL: collectionIconURL,
                                       textContentURL: textContentURL)
            case .none:
                imageView.contentMode = .scaleAspectFit
                imageView.image = R.image.inscription_intaglio()
                textContentView?.isHidden = true
            }
            setNeedsLayout()
        }
    }
    
    var reportsNoIntrinsicContentSize = false
    
    override var intrinsicContentSize: CGSize {
        if reportsNoIntrinsicContentSize {
            CGSize(
                width: UIView.noIntrinsicMetric,
                height: UIView.noIntrinsicMetric,
            )
        } else {
            super.intrinsicContentSize
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
        super.layoutSubviews()
        if content == nil {
            imageView.frame.size = CGSize(width: bounds.width / 2, height: bounds.height / 2)
        } else {
            imageView.frame.size = CGSize(width: bounds.width, height: bounds.height)
        }
        imageView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        if let textContentView, bounds.width > 0, bounds.height > 0 {
            // Preserve room for the text by scaling the entire 42-point icon layout.
            let scale = min(1, min(bounds.width, bounds.height) / 42)
            textContentView.bounds = CGRect(
                x: 0,
                y: 0,
                width: bounds.width / scale - 12,
                height: bounds.height / scale - 9,
            )
            textContentView.transform = CGAffineTransform(scaleX: scale, y: scale)
            textContentView.center = CGPoint(
                x: bounds.width / 2,
                y: bounds.height / 2 - scale / 2,
            )
        }
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
