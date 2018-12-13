import UIKit
import Photos
import MobileCoreServices

class PhotoPickerCell: UICollectionViewCell {
    
    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var fileTypeView: UIView!
    @IBOutlet weak var gifLabel: UILabel!
    @IBOutlet weak var videoImageView: UIImageView!
    @IBOutlet weak var durationLabel: UILabel!
    
    private let utiCheckingImageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        return options
    }()
    
    var requestId: PHImageRequestID = -1
    var localIdentifier: String!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        PHCachingImageManager.default().cancelImageRequest(requestId)
    }
    
    func updateFileTypeView(asset: PHAsset) {
        if asset.mediaType == .video {
            gifLabel.isHidden = true
            videoImageView.isHidden = false
            durationLabel.text = mediaDurationFormatter.string(from: asset.duration)
            fileTypeView.isHidden = false
        } else {
            PHImageManager.default().requestImageData(for: asset, options: utiCheckingImageRequestOptions, resultHandler: { [weak self] (_, uti, _, _) in
                guard let weakSelf = self, weakSelf.localIdentifier == asset.localIdentifier else {
                    return
                }
                if let uti = uti, UTTypeConformsTo(uti as CFString, kUTTypeGIF) {
                    weakSelf.gifLabel.isHidden = false
                    weakSelf.videoImageView.isHidden = true
                    weakSelf.durationLabel.text = nil
                    weakSelf.fileTypeView.isHidden = false
                } else {
                    weakSelf.fileTypeView.isHidden = true
                }
            })
        }
    }
    
}
