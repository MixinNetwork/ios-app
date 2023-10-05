import UIKit
import LinkPresentation
import QRCode
import MixinServices

class QRCodeViewController: UIViewController {
    
    enum CenterView {
        case avatar((AvatarImageView) -> Void)
        case receiveMoney((AvatarImageView) -> Void)
        case asset(AssetItem)
    }
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var codeImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    
    let isShowingAccount: Bool
    
    private let codeContent: String
    private let foregroundColor: UIColor
    private let centerView: CenterView
    private let codeDescription: String
    private let centerViewDimension: CGFloat = 40
    
    init(
        title: String,
        content: String,
        foregroundColor: UIColor,
        description: String,
        centerView: CenterView,
        isShowingAccount: Bool = false
    ) {
        self.codeContent = content
        self.foregroundColor = foregroundColor
        self.centerView = centerView
        self.codeDescription = description
        self.isShowingAccount = isShowingAccount
        let nib = R.nib.qrCodeView
        super.init(nibName: nib.name, bundle: nib.bundle)
        self.title = title
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = PopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    convenience init(account: Account) {
        let light = UITraitCollection(userInterfaceStyle: .light)
        self.init(title: R.string.localizable.my_qr_code(),
                  content: account.codeURL,
                  foregroundColor: UIColor.theme.resolvedColor(with: light),
                  description: R.string.localizable.scan_code_add_me(),
                  centerView: .avatar({ $0.setImage(with: account) }),
                  isShowingAccount: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        titleView.titleLabel.text = title
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        descriptionLabel.text = codeDescription
        
        switch centerView {
        case .avatar(let avatarSetter):
            let avatarImageView = AvatarImageView()
            avatarImageView.overrideUserInterfaceStyle = .light
            contentView.addSubview(avatarImageView)
            avatarImageView.snp.makeConstraints { make in
                make.center.equalTo(codeImageView.snp.center)
                make.width.height.equalTo(centerViewDimension)
            }
            avatarSetter(avatarImageView)
        case .receiveMoney(let avatarSetter):
            let avatarImageView = AvatarImageView()
            avatarImageView.overrideUserInterfaceStyle = .light
            contentView.addSubview(avatarImageView)
            avatarImageView.snp.makeConstraints { make in
                make.center.equalTo(codeImageView.snp.center)
                make.width.height.equalTo(centerViewDimension)
            }
            avatarSetter(avatarImageView)
            
            let iconView = UIImageView(image: R.image.ic_receive_money())
            iconView.backgroundColor = .clear
            iconView.overrideUserInterfaceStyle = .light
            contentView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.trailing.bottom.equalTo(avatarImageView)
            }
        case .asset(let asset):
            let iconView = AssetIconView()
            iconView.overrideUserInterfaceStyle = .light
            contentView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.center.equalTo(codeImageView.snp.center)
                make.width.height.equalTo(centerViewDimension)
            }
            iconView.setIcon(asset: asset)
        }
        
        codeImageView.layer.cornerCurve = .continuous
        codeImageView.layer.cornerRadius = 14
        
        let foregroundColor = self.foregroundColor.cgColor
        let backgroundColor = UIColor.white.cgColor
        let qrCodePixelDimension = imageViewWidthConstraint.constant * AppDelegate.current.mainWindow.screen.scale
        let qrCodePixelSize = CGSize(width: qrCodePixelDimension, height: qrCodePixelDimension)
        DispatchQueue.global().async { [weak self, codeContent] in
            let generator = QRCodeGenerator_External()
            let document = QRCode.Document(utf8String: codeContent, errorCorrection: .quantize, generator: generator)
            document.design = {
                let design = QRCode.Design(foregroundColor: foregroundColor, backgroundColor: backgroundColor)
                design.shape = {
                    let shape = QRCode.Shape()
                    shape.eye = QRCode.EyeShape.Squircle()
                    shape.onPixels = QRCode.PixelShape.Circle()
                    return shape
                }()
                return design
            }()
            guard let cgImage = document.cgImage(qrCodePixelSize) else {
                return
            }
            DispatchQueue.main.async {
                self?.codeImageView.image = UIImage(cgImage: cgImage)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @objc func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBAction func scan(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        UIApplication.homeViewController?.showCamera(asQrCodeScanner: true)
    }
    
    @IBAction func shareImage(_ sender: Any) {
        let renderer = UIGraphicsImageRenderer(bounds: contentView.bounds)
        let image = renderer.image { (context) in
            contentView.layer.render(in: context.cgContext)
        }
        let item = ActivityItem(image: image, title: title)
        let activity = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        present(activity, animated: true)
    }
    
    private func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        let width = view.bounds.width
        let fittingSize = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        preferredContentSize.height = view.systemLayoutSizeFitting(fittingSize).height
    }
    
}

extension QRCodeViewController {
    
    private class ActivityItem: NSObject, UIActivityItemSource {
        
        private let image: UIImage
        private let title: String?

        init(image: UIImage, title: String?) {
            self.image = image
            self.title = title
            super.init()
        }
        
        func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
            image
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            image
        }
        
        func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
            if let title {
                let meta = LPLinkMetadata()
                meta.title = title
                return meta
            } else {
                return nil
            }
        }
        
    }
    
}
