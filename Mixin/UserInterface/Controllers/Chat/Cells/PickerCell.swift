import UIKit
import Photos
import MobileCoreServices
import MixinServices

class PickerCell: UICollectionViewCell {
    
    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var fileTypeView: UIView!
    @IBOutlet weak var gifLabel: UILabel!
    @IBOutlet weak var videoImageView: UIImageView!
    @IBOutlet weak var durationLabel: UILabel!
    
    var localIdentifier: String?
    var requestId: PHImageRequestID?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if let id = requestId {
            PHCachingImageManager.default().cancelImageRequest(id)
        }
    }
    
}
