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
        self.linkView = linkView
        self.contentView = ShareObiSurroundedView<DepositLinkView>(contentView: linkView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.backgroundColor = R.color.background()
        layoutWrapperHeightConstraint.isActive = false
        linkView.size = .small
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
        
        let contentView: ContentView
        let obiView = ShareObiView()
        
        init(contentView: ContentView) {
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
                make.top.equalTo(contentView.snp.bottom).offset(36)
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
