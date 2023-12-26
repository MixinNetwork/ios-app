import UIKit
import LinkPresentation
import QRCode
import MixinServices

class QRCodeViewController: UIViewController {
    
    enum CenterContent {
        case avatar((AvatarImageView) -> Void)
        case receiveMoney((AvatarImageView) -> Void)
        case asset(TokenItem)
    }
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var centerContentWrapperView: UIView!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    
    let isShowingAccount: Bool
    
    private let codeContent: String
    private let foregroundColor: UIColor
    private let centerContent: CenterContent
    private let codeDescription: String
    private let centerViewDimension: CGFloat = 40
    
    init(
        title: String,
        content: String,
        foregroundColor: UIColor,
        description: String,
        centerContent: CenterContent,
        isShowingAccount: Bool = false
    ) {
        self.codeContent = content
        self.foregroundColor = foregroundColor
        self.centerContent = centerContent
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
                  centerContent: .avatar({ $0.setImage(with: account) }),
                  isShowingAccount: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        titleView.titleLabel.text = title
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        descriptionLabel.text = codeDescription
        centerContentWrapperView.overrideUserInterfaceStyle = .light
        
        switch centerContent {
        case .avatar(let avatarSetter):
            let avatarImageView = AvatarImageView()
            centerContentWrapperView.addSubview(avatarImageView)
            avatarImageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(centerViewDimension)
            }
            avatarSetter(avatarImageView)
        case .receiveMoney(let avatarSetter):
            let avatarImageView = AvatarImageView()
            centerContentWrapperView.addSubview(avatarImageView)
            avatarImageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(centerViewDimension)
            }
            avatarSetter(avatarImageView)
            
            let iconView = UIImageView(image: R.image.ic_receive_money())
            iconView.backgroundColor = .clear
            centerContentWrapperView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.trailing.bottom.equalTo(avatarImageView)
            }
        case .asset(let asset):
            let iconView = AssetIconView()
            centerContentWrapperView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(centerViewDimension)
            }
            iconView.setIcon(token: asset)
        }
        
        qrCodeView.setDefaultCornerCurve()
        qrCodeView.tintColor = self.foregroundColor
        
        let size = CGSize(width: imageViewWidthConstraint.constant,
                          height: imageViewWidthConstraint.constant)
        centerContentWrapperView.isHidden = true
        qrCodeView.setContent(codeContent, size: size) {
            self.centerContentWrapperView.isHidden = false
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
        UIApplication.homeNavigationController?.pushCameraViewController(asQRCodeScanner: true)
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
