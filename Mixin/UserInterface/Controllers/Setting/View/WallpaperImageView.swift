import UIKit

final class WallpaperImageView: UIImageView {
    
    private let imageMaskView = UIView()
    
    var wallpaper: Wallpaper? {
        didSet {
            if let wallpaper = wallpaper {
                image = wallpaper.image
                contentMode = wallpaper.contentMode(imageViewSize: frame.size)
                imageMaskView.isHidden = !wallpaper.showMaskView
            } else {
                image = R.image.conversation.ic_photo()
                contentMode = .center
                imageMaskView.isHidden = true
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
    
    private func prepare() {
        clipsToBounds = true
        contentMode = .scaleAspectFill
        addSubview(imageMaskView)
        imageMaskView.snp.makeEdgesEqualToSuperview()
        imageMaskView.backgroundColor = .black.withAlphaComponent(0.1)
        imageMaskView.isHidden = true
    }
    
}
