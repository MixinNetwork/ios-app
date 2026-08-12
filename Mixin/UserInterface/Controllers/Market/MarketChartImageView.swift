import UIKit
import SDWebImage

final class MarketChartImageView: MarketColorTintedImageView {
    
    override var image: UIImage? {
        get {
            super.image
        }
        set {
            super.image = newValue?.withRenderingMode(.alwaysTemplate)
        }
    }
    
    func setChartImage(url: URL?) {
        sd_setImage(
            with: url,
            placeholderImage: nil,
            options: .refreshCached,
            context: [
                // Magic key that gives bitmap based UIImage, which available for tint color behavior
                .imageThumbnailPixelSize: CGSize.zero,
            ]
        )
    }
    
    func prepareForReuse() {
        sd_cancelCurrentImageLoad()
        super.image = nil
    }
    
}
