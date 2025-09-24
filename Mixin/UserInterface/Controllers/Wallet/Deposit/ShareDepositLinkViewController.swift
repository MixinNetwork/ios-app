import UIKit
import Photos
import MixinServices

final class ShareDepositLinkViewController: ShareViewAsPictureViewController {
    
    private let link: DepositLink
    
    private weak var linkView: DepositLinkView!
    
    init(link: DepositLink) {
        self.link = link
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func loadContentView() {
        let linkView = DepositLinkView()
        let contentView = switch link.chain {
        case .mixin:
            ShareObiSurroundedView<DepositLinkView>(contentView: linkView, spacing: .normal)
        case .native(let native):
            ShareObiSurroundedView<DepositLinkView>(contentView: linkView, spacing: .compact)
        }
        self.linkView = linkView
        self.contentView = contentView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.backgroundColor = R.color.background()
        layoutWrapperHeightConstraint.isActive = false
        linkView.adjustsFontForContentSizeCategory = false
        switch ScreenHeight.current {
        case .short, .medium:
            linkView.size = .small
        default:
            linkView.size = .medium
        }
        linkView.load(link: link)
        actionButtonBackgroundView.effect = nil
        actionButtonTrayView.backgroundColor = R.color.background()
    }
    
    override func share(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        let image = makeImage()
        let title = switch link.chain {
        case .mixin:
            R.string.localizable.receive_money()
        case .native:
            linkView.titleLabel.text
        }
        let item = QRCodeActivityItem(image: image, title: title)
        let activity = UIActivityViewController(
            activityItems: [item],
            applicationActivities: nil
        )
        presentingViewController.dismiss(animated: true) {
            presentingViewController.present(activity, animated: true)
        }
    }
    
    override func copyLink(_ sender: Any) {
        UIPasteboard.general.string = link.value
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        close(sender)
    }
    
    override func savePhoto(_ sender: Any) {
        let image = makeImage()
        PHPhotoLibrary.checkAuthorization { (isAuthorized) in
            guard isAuthorized else {
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    self.close(sender)
                    if success {
                        showAutoHiddenHud(style: .notification, text: R.string.localizable.photo_saved())
                    } else {
                        showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_save_photo())
                    }
                }
            }
        }
    }
    
}

extension ShareDepositLinkViewController {
    
    private final class ShareObiSurroundedView<ContentView: UIView>: UIView {
        
        enum Spacing {
            case normal
            case compact
        }
        
        let contentView: ContentView
        let obiView = ShareObiView()
        
        init(contentView: ContentView, spacing: Spacing) {
            self.contentView = contentView
            super.init(frame: .zero)
            addSubview(contentView)
            contentView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(54)
                make.leading.equalToSuperview().offset(18)
                make.trailing.equalToSuperview().offset(-18)
            }
            addSubview(obiView)
            obiView.snp.makeConstraints { make in
                make.leading.trailing.bottom.equalToSuperview()
                switch spacing {
                case .normal:
                    switch ScreenHeight.current {
                    case .short:
                        make.top.equalTo(contentView.snp.bottom).offset(24)
                    case .medium:
                        make.top.equalTo(contentView.snp.bottom).offset(32)
                    default:
                        make.top.equalTo(contentView.snp.bottom).offset(36)
                    }
                case .compact:
                    switch ScreenHeight.current {
                    case .short:
                        make.top.equalTo(contentView.snp.bottom).offset(4)
                    case .medium:
                        make.top.equalTo(contentView.snp.bottom).offset(8)
                    default:
                        make.top.equalTo(contentView.snp.bottom).offset(36)
                    }
                }
                make.height.equalTo(100)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("Storyboard/Xib not supported")
        }
        
    }
    
    private func makeImage() -> UIImage {
        let canvas = contentView.bounds
        let renderer = UIGraphicsImageRenderer(bounds: canvas)
        contentView.layer.cornerRadius = 0
        let image = renderer.image { context in
            contentView.drawHierarchy(in: canvas, afterScreenUpdates: true)
        }
        contentView.layer.cornerRadius = contentViewCornerRadius
        return image
    }
    
}
