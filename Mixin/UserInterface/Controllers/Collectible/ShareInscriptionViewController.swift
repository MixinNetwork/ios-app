import UIKit
import LinkPresentation
import MixinServices

final class ShareInscriptionViewController: ShareViewAsPictureViewController<ShareInscriptionAsPictureView> {
    
    private let inscription: InscriptionItem
    
    init(inscription: InscriptionItem, token: MixinTokenItem) {
        self.inscription = inscription
        let contentView = R.nib.shareInscriptionAsPictureView(withOwner: nil)!
        contentView.reloadData(inscription: inscription, token: token)
        super.init(contentView: contentView, size: CGSize(width: 315, height: 529))
        overrideUserInterfaceStyle = .dark
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func share(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        let activity: UIActivityViewController
        if let url = URL(string: inscription.shareLink) {
            let item = ActivityItem(
                url: url,
                image: contentView.contentImageView.image,
                title: inscription.collectionSequenceRepresentation
            )
            activity = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        } else {
            activity = UIActivityViewController(activityItems: [link], applicationActivities: nil)
        }
        presentingViewController.dismiss(animated: true) {
            presentingViewController.present(activity, animated: true)
        }
    }
    
    override func copyLink(_ sender: Any) {
        UIPasteboard.general.string = inscription.shareLink
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        close(sender)
    }
    
    override func savePhoto(_ sender: Any) {
        let image = makeImage()
        PhotoLibrary.saveImage(source: .image(image)) { alert in
            self.present(alert, animated: true)
        }
        close(sender)
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
    
}
