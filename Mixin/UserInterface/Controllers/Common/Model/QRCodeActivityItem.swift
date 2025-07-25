import UIKit
import LinkPresentation

final class QRCodeActivityItem: NSObject, UIActivityItemSource {
    
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
