import UIKit
import SDWebImage
import MixinServices

class SharedMediaCell: UICollectionViewCell {
    
    @IBOutlet weak var imageWrapperView: VerticalPositioningImageView!
    @IBOutlet weak var mediaTypeView: SharedMediaTypeOverlayView!
    
    var item: GalleryItem?
    
    var imageView: SDAnimatedImageView {
        return imageWrapperView.imageView
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        imageView.autoPlayAnimatedImage = false
    }
    
    func render(item: GalleryItem) {
        self.item = item
        let placeholder: UIImage?
        switch item.thumbnail {
        case .image(let image):
            placeholder = image
        case .url(let url):
            placeholder = UIImage(contentsOfFile: url.path)
        case .none:
            placeholder = nil
        }
        imageWrapperView.aspectRatio = item.size
        imageWrapperView.position = item.shouldLayoutAsArticle ? .relativeOffset(0) : .center
        imageView.sd_setImage(with: item.url, placeholderImage: placeholder, context: localImageContext)
        switch item.category {
        case .image:
            if item.mediaMimeType?.contains("gif") ?? false {
                mediaTypeView.style = .gif
            } else {
                mediaTypeView.style = .hidden
            }
        case .video:
            let duration = TimeInterval(item.mediaDuration) / millisecondsPerSecond
            mediaTypeView.style = .video(duration: duration)
        case .live:
            mediaTypeView.style = .hidden
        }
    }
    
}

extension SharedMediaCell: GalleryTransitionSource {
    
    var transitionViewType: GalleryTransitionView.Type {
        return GalleryTransitionFromSharedMediaView.self
    }
    
    var direction: GalleryItemModelController.Direction {
        return .backward
    }
    
}
