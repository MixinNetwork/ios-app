import UIKit
import Photos
import LinkPresentation
import MixinServices

final class ShareInscriptionViewController: UIViewController {
    
    @IBOutlet weak var layoutWrapperView: UIView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var contentImageView: UIImageView!
    @IBOutlet weak var collectionNameLabel: UILabel!
    @IBOutlet weak var collectionSequenceLabel: UILabel!
    @IBOutlet weak var inscriptionHashView: InscriptionHashView!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var tokenIconBackgroundView: UIView!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    @IBOutlet weak var actionButtonTrayView: UIView!
    @IBOutlet weak var actionButtonStackView: UIStackView!
    
    var inscription: InscriptionItem? {
        didSet {
            guard let inscription, isViewLoaded else {
                return
            }
            reloadData(with: inscription)
        }
    }
    
    var token: TokenItem? {
        didSet {
            guard isViewLoaded else {
                return
            }
            reloadData(with: token)
        }
    }
    
    private let contentViewCornerRadius: CGFloat = 12
    
    init() {
        let nib = R.nib.shareInscriptionView
        super.init(nibName: nib.name, bundle: nib.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        overrideUserInterfaceStyle = .dark
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let view = view as? TouchEventBypassView {
            view.exception = layoutWrapperView
        }
        contentView.layer.cornerRadius = contentViewCornerRadius
        qrCodeView.layer.cornerCurve = .continuous
        qrCodeView.layer.cornerRadius = 7
        qrCodeView.layer.masksToBounds = true
        let tokenIconBackgroundMask = UIImageView(image: R.image.collection_token_mask())
        tokenIconBackgroundMask.frame = tokenIconBackgroundView.bounds
        tokenIconBackgroundView.mask = tokenIconBackgroundMask
        tokenIconBackgroundView.layer.borderColor = UIColor.white.cgColor
        tokenIconBackgroundView.layer.borderWidth = 1
        addActionButton(
            icon: R.image.web.ic_action_share(),
            text: R.string.localizable.share()
        ) { button in
            button.addTarget(self, action: #selector(share(_:)), for: .touchUpInside)
        }
        addActionButton(
            icon: R.image.web.ic_action_copy(),
            text: R.string.localizable.link()
        ) { button in
            button.addTarget(self, action: #selector(copyLink(_:)), for: .touchUpInside)
        }
        addActionButton(
            icon: R.image.action_save(),
            text: R.string.localizable.save()
        ) { button in
            button.addTarget(self, action: #selector(savePhoto(_:)), for: .touchUpInside)
        }
        if let inscription {
            reloadData(with: inscription)
        }
        if let token {
            reloadData(with: token)
        }
    }
    
    @IBAction func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func share(_ sender: Any) {
        guard let inscription, let presentingViewController else {
            return
        }
        let activity: UIActivityViewController
        if let url = URL(string: inscription.shareLink) {
            let item = ActivityItem(url: url,
                                    image: contentImageView.image,
                                    title: inscription.collectionSequenceRepresentation)
            activity = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        } else {
            activity = UIActivityViewController(activityItems: [link], applicationActivities: nil)
        }
        presentingViewController.dismiss(animated: true) {
            presentingViewController.present(activity, animated: true)
        }
    }
    
    @objc private func copyLink(_ sender: Any) {
        guard let inscription else {
            return
        }
        UIPasteboard.general.string = inscription.shareLink
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        close(sender)
    }
    
    @objc private func savePhoto(_ sender: Any) {
        let canvas = contentView.bounds
        let renderer = UIGraphicsImageRenderer(bounds: canvas)
        contentView.layer.cornerRadius = 0
        let image = renderer.image { context in
            contentView.drawHierarchy(in: canvas, afterScreenUpdates: true)
        }
        contentView.layer.cornerRadius = contentViewCornerRadius
        PHPhotoLibrary.checkAuthorization { (isAuthorized) in
            guard isAuthorized else {
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { (success: Bool, error: Error?) in
                DispatchQueue.main.async {
                    self.close(sender)
                    if success {
                        showAutoHiddenHud(style: .notification, text: R.string.localizable.photo_saved())
                    } else {
                        showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_save_photo())
                    }
                }
            })
        }
    }
    
}

extension ShareInscriptionViewController {
    
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
    
    private class ActivityItem: NSObject, UIActivityItemSource {
        
        private let url: URL
        private let image: UIImage?
        private let title: String?
        
        init(url: URL, image: UIImage?, title: String?) {
            self.url = url
            self.image = image
            self.title = title
            super.init()
        }
        
        func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
            url
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            url
        }
        
        func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
            let meta = LPLinkMetadata()
            if let image {
                meta.imageProvider = NSItemProvider(object: image)
            }
            if let title {
                meta.title = title
            } else {
                meta.title = url.absoluteString
            }
            return meta
        }
        
    }
    
    private func addActionButton(icon: UIImage?, text: String, config: (UIButton) -> Void) {
        let iconTrayView = UIImageView(image: R.image.explore.action_tray())
        let label = UILabel()
        label.textColor = R.color.text()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        let stackView = UIStackView(arrangedSubviews: [iconTrayView, label])
        stackView.axis = .vertical
        stackView.spacing = 8
        actionButtonStackView.addArrangedSubview(stackView)
        
        let iconView = UIImageView(image: icon?.withRenderingMode(.alwaysTemplate))
        iconView.tintColor = R.color.text()
        actionButtonTrayView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.center.equalTo(iconTrayView.snp.center)
        }
        
        let button = UIButton()
        config(button)
        actionButtonTrayView.addSubview(button)
        button.snp.makeConstraints { make in
            make.edges.equalTo(stackView)
        }
    }
    
    private func reloadData(with inscription: InscriptionItem) {
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
            contentView.addSubview(textContentView)
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
    }
    
    private func reloadData(with token: TokenItem?) {
        if let token {
            tokenIconView.isHidden = false
            tokenIconView.setIcon(token: token)
        } else {
            tokenIconView.isHidden = true
        }
    }
    
}