import UIKit
import Photos
import SDWebImage
import CoreServices
import MixinServices

class MediaPreviewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var selectedStatusImageView: UIImageView!
    @IBOutlet weak var mediaTypeView: MediaTypeOverlayView!
    
    private var requestId: PHImageRequestID?
    private lazy var imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        return options
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedStatusImageView.isHidden = false
        mediaTypeView.videoTypeView.spacing = 8
        mediaTypeView.typeViewBottomConstraint.constant = 8
        mediaTypeView.gifFileTypeView.font = .systemFont(ofSize: 16)
        mediaTypeView.videoDurationLabel.font = .systemFont(ofSize: 16)
        mediaTypeView.videoImageView.image = R.image.conversation.ic_video_bold()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        if let id = requestId {
            PHCachingImageManager.default().cancelImageRequest(id)
        }
    }
    
    func load(asset: PHAsset, size: CGSize) {
        if asset.mediaType == .video {
            mediaTypeView.style = .video(duration: asset.duration)
        } else {
            if let uti = asset.uniformTypeIdentifier, UTTypeConformsTo(uti as CFString, kUTTypeGIF) {
                mediaTypeView.style = .gif
            } else {
                mediaTypeView.style = .hidden
            }
        }
        requestId = PHImageManager.default().requestImage(for: asset, targetSize: size * UIScreen.main.scale, contentMode: .aspectFill, options: imageRequestOptions) { [weak self] (image, info) in
            self?.imageView.image = image
        }
    }
    
    func updateSelectedStatus(isSelected: Bool) {
        selectedStatusImageView.image = isSelected ? R.image.ic_photo_checkmark() : R.image.ic_photo_unselected()
    }
    
}
