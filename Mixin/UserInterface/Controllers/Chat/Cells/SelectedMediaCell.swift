import UIKit
import Photos
import SDWebImage
import CoreServices
import MixinServices

class SelectedMediaCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: SDAnimatedImageView!
    @IBOutlet weak var mediaTypeView: MediaTypeOverlayView!
    
    var onRemove: (() -> Void)?
    
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
    }
    
    func load(asset: PHAsset, size: CGSize) {
        if asset.mediaType == .video {
            mediaTypeView.style = .video(duration: asset.duration)
        } else {
            if let uti = asset.value(forKey: "uniformTypeIdentifier") as? String, UTTypeConformsTo(uti as CFString, kUTTypeGIF) {
                mediaTypeView.style = .gif
            } else {
                mediaTypeView.style = .hidden
            }
        }
        PHImageManager.default().requestImage(for: asset, targetSize: size * UIScreen.main.scale, contentMode: .aspectFill, options: imageRequestOptions) { [weak self] (image, info) in
            guard let self = self, let image = image else {
                return
            }
            self.imageView.image = image
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        onRemove?()
    }
    
}
