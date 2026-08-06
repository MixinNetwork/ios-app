import UIKit
import SDWebImage
import SnapKit

final class FavoriteButton: UIButton {
    
    struct Config {
        
        static let large = Config(
            favoriteImage: R.image.market_favorite_solid()!
                .withRenderingMode(.alwaysTemplate),
            notFavoriteImage: R.image.market_favorite_hollow()!
                .withRenderingMode(.alwaysTemplate),
            animationImage: {
                if let data = try? Data(contentsOf: R.file.favorite_largePng()!) {
                    SDAnimatedImage(data: data)
                } else {
                    nil
                }
            }(),
            animationSize: CGSize(width: 32, height: 32),
            duration: 1.25
        )
        
        static let medium = Config(
            favoriteImage: R.image.market_favorited()!
                .withRenderingMode(.alwaysTemplate),
            notFavoriteImage: R.image.market_unfavorited()!
                .withRenderingMode(.alwaysTemplate),
            animationImage: {
                if let data = try? Data(contentsOf: R.file.favorite_mediumPng()!) {
                    SDAnimatedImage(data: data)
                } else {
                    nil
                }
            }(),
            animationSize: CGSize(width: 20, height: 20),
            duration: 1.7
        )
        
        let favoriteImage: UIImage
        let notFavoriteImage: UIImage
        let animationImage: SDAnimatedImage?
        let animationSize: CGSize
        let duration: TimeInterval
        
    }
    
    private let config: Config
    
    private var isFavorite: Bool?
    
    private weak var animationImageView: UIView?
    
    init(config: Config) {
        self.config = config
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
    }
    
    required init?(coder: NSCoder) {
        self.config = .medium
        super.init(coder: coder)
    }
    
    func setFavorite(_ favorite: Bool?, animated: Bool) {
        self.isFavorite = favorite
        animationImageView?.removeFromSuperview()
        guard let favorite else {
            setImage(nil, for: .normal)
            return
        }
        if favorite {
            setImage(config.favoriteImage, for: .normal)
            if animated, let animationImage = config.animationImage {
                tintColor = .clear
                let animationImageView = SDAnimatedImageView(image: animationImage)
                animationImageView.contentMode = .scaleToFill
                animationImageView.shouldCustomLoopCount = true
                animationImageView.animationRepeatCount = 1
                addSubview(animationImageView)
                animationImageView.snp.makeConstraints { make in
                    make.size.equalTo(config.animationSize)
                    make.center.equalToSuperview()
                }
                self.animationImageView = animationImageView
                DispatchQueue.main.asyncAfter(deadline: .now() + config.duration) {
                    animationImageView.removeFromSuperview()
                    if self.isFavorite == favorite {
                        self.tintColor = UIColor(displayP3RgbValue: 0x4b7cdd)
                    }
                }
            } else {
                tintColor = UIColor(displayP3RgbValue: 0x4b7cdd)
            }
        } else {
            setImage(config.notFavoriteImage, for: .normal)
            tintColor = R.color.icon_tint()
        }
    }
    
}
