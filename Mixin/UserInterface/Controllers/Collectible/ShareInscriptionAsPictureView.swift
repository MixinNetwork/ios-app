import UIKit
import MixinServices

final class ShareInscriptionAsPictureView: UIView {
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var contentImageView: UIImageView!
    @IBOutlet weak var collectionNameLabel: UILabel!
    @IBOutlet weak var collectionSequenceLabel: UILabel!
    @IBOutlet weak var inscriptionHashView: InscriptionHashView!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var tokenIconBackgroundView: UIView!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        qrCodeView.layer.cornerCurve = .continuous
        qrCodeView.layer.cornerRadius = 7
        qrCodeView.layer.masksToBounds = true
        
        let tokenIconBackgroundMask = UIImageView(image: R.image.collection_token_mask())
        tokenIconBackgroundMask.frame = tokenIconBackgroundView.bounds
        tokenIconBackgroundView.mask = tokenIconBackgroundMask
        tokenIconBackgroundView.layer.borderColor = UIColor.white.cgColor
        tokenIconBackgroundView.layer.borderWidth = 1
    }
    
    func reloadData(inscription: InscriptionItem, token: TokenItem?) {
        switch inscription.inscriptionContent {
        case let .image(url):
            backgroundImageView.isHidden = false
            backgroundImageView.sd_setImage(with: url)
            contentImageView.contentMode = .scaleAspectFill
            contentImageView.sd_setImage(with: url)
        case let .text(collectionIconURL, textContentURL):
            backgroundImageView.isHidden = false
            backgroundImageView.sd_setImage(with: collectionIconURL)
            contentImageView.contentMode = .scaleToFill
            contentImageView.image = R.image.collectible_text_background()
            let textContentView = TextInscriptionContentView(iconDimension: 100, spacing: 10)
            textContentView.label.numberOfLines = 10
            textContentView.label.font = .systemFont(ofSize: 24, weight: .semibold)
            textContentView.label.adjustsFontSizeToFitWidth = true
            textContentView.label.minimumScaleFactor = 24 / 12
            addSubview(textContentView)
            textContentView.snp.makeConstraints { make in
                make.top.greaterThanOrEqualTo(contentImageView).offset(40)
                make.leading.equalTo(contentImageView).offset(30)
                make.trailing.equalTo(contentImageView).offset(-30)
                make.bottom.lessThanOrEqualTo(contentImageView).offset(-40)
                make.centerY.equalTo(contentImageView)
            }
            textContentView.reloadData(collectionIconURL: collectionIconURL,
                                       textContentURL: textContentURL)
        case .none:
            backgroundImageView.isHidden = true
            contentImageView.contentMode = .center
            contentImageView.image = R.image.inscription_intaglio()
        }
        collectionNameLabel.text = inscription.collectionName
        collectionSequenceLabel.text = inscription.sequenceRepresentation
        inscriptionHashView.content = inscription.inscriptionHash
        qrCodeView.setContent(inscription.shareLink, size: CGSize(width: 110, height: 110))
        
        if let token {
            tokenIconView.isHidden = false
            tokenIconView.setIcon(token: token)
        } else {
            tokenIconView.isHidden = true
        }
    }
    
}

extension ShareInscriptionAsPictureView {
    
    @objc(ShareInscriptionDashLineView)
    final class DashLineView: UIView {
        
        private let lineWidth: CGFloat = 1
        private let lineColor: UIColor = UIColor(displayP3RgbValue: 0x6E7073, alpha: 1)
        private let numberOfDashes: CGFloat = 20
        private let lineLayer = CAShapeLayer()
        
        private var lastLayoutBounds: CGRect?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadLayer()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadLayer()
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            if lastLayoutBounds != bounds {
                lineLayer.frame.size = CGSize(width: bounds.width, height: lineWidth)
                lineLayer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
                
                let path = CGMutablePath()
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: bounds.width, y: 0))
                lineLayer.path = path
                
                let dashLength = bounds.width / (numberOfDashes * 2 + 1)
                lineLayer.lineDashPattern = [NSNumber(value: dashLength), NSNumber(value: dashLength)]
                
                lastLayoutBounds = bounds
            }
        }
        
        private func loadLayer() {
            lineLayer.fillColor = UIColor.clear.cgColor
            lineLayer.strokeColor = lineColor.cgColor
            lineLayer.lineWidth = lineWidth
            lineLayer.lineJoin = .round
            layer.addSublayer(lineLayer)
        }
        
    }
    
}
