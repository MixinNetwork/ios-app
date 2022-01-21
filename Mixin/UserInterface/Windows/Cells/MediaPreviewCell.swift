import UIKit
import Photos
import SDWebImage
import CoreServices
import MixinServices

class MediaPreviewCell: UICollectionViewCell {

    static let reuseIdentifier = "cell_identifier_media_preview_cell"
    static let cellSize = CGSize(width: 312, height: 312)
    
    @IBOutlet weak var imageView: SDAnimatedImageView!
    @IBOutlet weak var badge: BadgeView!
    @IBOutlet weak var checkmarkImageView: UIImageView!
    @IBOutlet weak var mediaTypeView: MediaTypeOverlayView!
    
    private lazy var imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        return options
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        badge.cornerRadius = 12
        badge.borderWidth = 1
        badge.borderColor = .white
        badge.badgeColor = .black.withAlphaComponent(0.16)
        badge.isHidden = true
        checkmarkImageView.isHidden = false
        mediaTypeView.videoTypeView.spacing = 8
        mediaTypeView.typeViewBottomConstraint.constant = 8
        mediaTypeView.gifFileTypeView.font = .systemFont(ofSize: 16)
        mediaTypeView.videoDurationLabel.font = .systemFont(ofSize: 16)
        mediaTypeView.videoImageView.image = R.image.conversation.ic_video_bold()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
    
    func load(asset: PHAsset) {
        if asset.mediaType == .video {
            mediaTypeView.style = .video(duration: asset.duration)
        } else {
            if let uti = asset.value(forKey: "uniformTypeIdentifier") as? String, UTTypeConformsTo(uti as CFString, kUTTypeGIF) {
                mediaTypeView.style = .gif
            } else {
                mediaTypeView.style = .hidden
            }
        }
        let targetSize = Self.cellSize * UIScreen.main.scale
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: imageRequestOptions) { [weak self] (image, info) in
            guard let self = self, let image = image else {
                return
            }
            self.imageView.image = image
        }
    }
    
    func updateSelectedStatus(isSelected: Bool) {
        checkmarkImageView.isHidden = !isSelected
        badge.isHidden = isSelected
    }
    
}
