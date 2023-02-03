import UIKit
import Photos
import SDWebImage
import CoreServices
import MixinServices

class SelectedMediaCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var mediaTypeView: MediaTypeOverlayView!
    
    var deselectAsset: (() -> Void)?
    
    private var requestId: PHImageRequestID?
    private lazy var imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        return options
    }()
    
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
    
    @IBAction func closeAction(_ sender: Any) {
        deselectAsset?()
    }
    
}
