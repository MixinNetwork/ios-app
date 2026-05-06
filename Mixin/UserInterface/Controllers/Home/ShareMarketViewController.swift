import UIKit
import LinkPresentation

final class ShareMarketViewController: ShareViewAsPictureViewController<ShareMarketAsPictureView> {
    
    private let symbol: String
    private let image: UIImage
    
    private var dismissOnColorAppearanceChange = false
    
    init(symbol: String, image: UIImage) {
        self.symbol = symbol
        self.image = image
        let contentView = R.nib.shareMarketAsPictureView(withOwner: nil)!
        contentView.setImage(image)
        super.init(contentView: contentView, size: CGSize(width: 295, height: 547))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        actionButtonBackgroundView.effect = nil
        actionButtonTrayView.backgroundColor = R.color.background()
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
        let image = makeImage()
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
        let image = makeImage()
        PhotoLibrary.saveImage(source: .image(image)) { alert in
            self.present(alert, animated: true)
        }
    }
    
    override func makeImage() -> UIImage {
        let view: UIView = contentView.screenshotWrapperView
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
