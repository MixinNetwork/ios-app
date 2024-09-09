import UIKit
import Photos
import LinkPresentation

final class ShareMarketViewController: ShareViewAsPictureViewController {
    
    private let symbol: String
    private let image: UIImage
    private let shareMarketContentView = R.nib.shareMarketAsPictureView(withOwner: nil)!
    
    private var dismissOnColorAppearanceChange = false
    
    init(symbol: String, image: UIImage) {
        self.symbol = symbol
        self.image = image
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func loadContentView() {
        contentView = shareMarketContentView
        shareMarketContentView.setImage(image)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        actionButtonBackgroundView.effect = nil
        actionButtonTrayView.backgroundColor = R.color.background()
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        switch traitCollection.userInterfaceStyle {
        case .dark:
            closeButtonEffectView.effect = .lightBlur
        case .light, .unspecified:
            fallthrough
        @unknown default:
            closeButtonEffectView.effect = .darkBlur
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        dismissOnColorAppearanceChange = true
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if dismissOnColorAppearanceChange,
           traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection)
        {
            presentingViewController?.dismiss(animated: false)
        }
    }
    
    override func share(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        let image = makeSharingImage()
        let item = ActivityItem(
            title: symbol + " " + R.string.localizable.market(),
            image: image
        )
        let activity = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        presentingViewController.dismiss(animated: true) {
            presentingViewController.present(activity, animated: true)
        }
    }
    
    override func copyLink(_ sender: Any) {
        UIPasteboard.general.string = URL.shortMixinMessenger.absoluteString
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        close(sender)
    }
    
    override func savePhoto(_ sender: Any) {
        let image = makeSharingImage()
        PHPhotoLibrary.checkAuthorization { [image] (isAuthorized) in
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
    
    private func makeSharingImage() -> UIImage {
        let view: UIView = shareMarketContentView.screenshotWrapperView
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { context in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
    
    private class ActivityItem: NSObject, UIActivityItemSource {
        
        private let title: String
        private let image: UIImage
        
        init(title: String, image: UIImage) {
            self.title = title
            self.image = image
            super.init()
        }
        
        func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
            image
        }
        
        func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
            image
        }
        
        func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
            let meta = LPLinkMetadata()
            meta.imageProvider = NSItemProvider(object: image)
            meta.title = title
            return meta
        }
        
    }
    
}
