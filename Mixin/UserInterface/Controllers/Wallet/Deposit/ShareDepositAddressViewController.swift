import UIKit
import Photos
import MixinServices

final class ShareDepositAddressViewController: ShareViewAsPictureViewController {
    
    private let token: any Token
    private let address: String
    private let network: String?
    private let minimumDeposit: String?
    private let shareAddressContentView = R.nib.shareDepositAddressContentView(withOwner: nil)!
    
    init(token: any Token, address: String, network: String?, minimumDeposit: String?) {
        self.token = token
        self.address = address
        self.network = network
        self.minimumDeposit = minimumDeposit
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func loadContentView() {
        contentView = shareAddressContentView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layoutWrapperHeightConstraint.isActive = false
        shareAddressContentView.summaryView.load(
            token: token,
            address: address,
            network: network,
            minimumDeposit: minimumDeposit
        )
        actionButtonBackgroundView.effect = nil
        actionButtonTrayView.backgroundColor = R.color.background()
    }
    
    override func share(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        let image = makeImage()
        let title = shareAddressContentView.summaryView.titleLabel.text
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
        UIPasteboard.general.string = address
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
