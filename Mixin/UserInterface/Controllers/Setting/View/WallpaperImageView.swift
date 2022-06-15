import UIKit

final class WallpaperImageView: UIImageView {
    
    private let imageMaskView = UIView()
    
    var wallpaper: Wallpaper? {
        didSet {
            if let wallpaper = wallpaper {
                image = wallpaper.image
                imageMaskView.isHidden = !wallpaper.isCustom
                updateContentMode()
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateContentMode()
    }
    
    private func prepare() {
        clipsToBounds = true
        addSubview(imageMaskView)
        imageMaskView.snp.makeEdgesEqualToSuperview()
        imageMaskView.backgroundColor = .black.withAlphaComponent(0.1)
        imageMaskView.isHidden = true
    }
    
    private func updateContentMode() {
        switch wallpaper {
        case .custom:
            contentMode = .scaleAspectFill
        default:
            if let imageSize = image?.size {
                let isBackgroundImageUndersized = bounds.size.width > imageSize.width || bounds.size.height > imageSize.height
                contentMode = isBackgroundImageUndersized ? .scaleAspectFill : .center
            }
        }
    }
    
}
