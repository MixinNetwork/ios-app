import UIKit
import Photos
import MobileCoreServices

class PhotoPickerCell: UICollectionViewCell {
    
    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var fileTypeView: UIView!
    @IBOutlet weak var gifLabel: UILabel!
    @IBOutlet weak var videoImageView: UIImageView!
    @IBOutlet weak var durationLabel: UILabel!
    
    private let imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return options
    }()
    private let utiCheckingImageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        return options
    }()
    
    private var requestId = PHInvalidImageRequestID
    private var localIdentifier: String?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        fileTypeView.isHidden = true
        thumbImageView.image = nil
        PHCachingImageManager.default().cancelImageRequest(requestId)
    }
    
    func render(asset: PHAsset) {
        localIdentifier = asset.localIdentifier
        // Load thumb image
        let targetSize = thumbImageView.frame.size * 2
        requestId = PHCachingImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: imageRequestOptions) { [weak self] (image, _) in
            guard let weakSelf = self, weakSelf.localIdentifier == asset.localIdentifier else {
                return
            }
            weakSelf.thumbImageView.image = image
        }
        // Load file type
        if asset.mediaType == .video {
            gifLabel.isHidden = true
            videoImageView.isHidden = false
            durationLabel.text = mediaDurationFormatter.string(from: asset.duration)
            fileTypeView.isHidden = false
        } else {
            // Callback will perform synchronously according to utiCheckingImageRequestOptions
            PHImageManager.default().requestImageData(for: asset, options: utiCheckingImageRequestOptions, resultHandler: { (_, uti, _, _) in
                if let uti = uti, UTTypeConformsTo(uti as CFString, kUTTypeGIF) {
                    self.gifLabel.isHidden = false
                    self.videoImageView.isHidden = true
                    self.durationLabel.text = nil
                    self.fileTypeView.isHidden = false
                } else {
                    self.fileTypeView.isHidden = true
                }
            })
        }
    }
    
}
