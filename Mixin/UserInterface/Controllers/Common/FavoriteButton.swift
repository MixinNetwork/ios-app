import UIKit
import SDWebImage
import SnapKit

final class FavoriteButton: UIButton {
    
    private var isFavorite: Bool?
    
    private weak var animationImageView: UIView?
    
    private var favoriteImage: UIImage {
        R.image.market_favorite_solid()!.withRenderingMode(.alwaysTemplate)
    }
    
    private var notFavoriteImage: UIImage {
        R.image.market_favorite_hollow()!.withRenderingMode(.alwaysTemplate)
    }
    
    func setFavorite(_ favorite: Bool?, animated: Bool) {
        self.isFavorite = favorite
        guard let favorite else {
            animationImageView?.removeFromSuperview()
            setImage(nil, for: .normal)
            return
        }
        if favorite {
            setImage(favoriteImage, for: .normal)
            if animated, let data = try? Data(contentsOf: R.file.favoritePng()!) {
                tintColor = .clear
                let image = SDAnimatedImage(data: data)
                let animationImageView = SDAnimatedImageView(image: image)
                animationImageView.contentMode = .scaleToFill
                animationImageView.shouldCustomLoopCount = true
                animationImageView.animationRepeatCount = 1
                addSubview(animationImageView)
                animationImageView.snp.makeConstraints { make in
                    make.size.equalTo(32)
                    make.center.equalToSuperview()
                }
                self.animationImageView = animationImageView
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                    animationImageView.removeFromSuperview()
                    if self.isFavorite == favorite {
                        self.tintColor = UIColor(displayP3RgbValue: 0x4b7cdd)
                    }
                }
            } else {
                animationImageView?.removeFromSuperview()
                tintColor = R.color.theme()
            }
        } else {
            animationImageView?.removeFromSuperview()
            setImage(notFavoriteImage, for: .normal)
            tintColor = R.color.icon_tint()
        }
    }
    
}
