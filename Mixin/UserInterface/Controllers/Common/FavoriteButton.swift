import UIKit
import SDWebImage
import SnapKit

final class FavoriteButton: UIButton {
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: 44, height: 44)
    }
    
    private let config: Config
    
    private var isFavorite: Bool?
    
    private weak var animationImageView: UIView?
    
    init(config: Config) {
        self.config = config
        super.init(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
    }
    
    required init?(coder: NSCoder) {
        self.config = .listCell
        super.init(coder: coder)
    }
    
    func setFavorite(_ favorite: Bool, animated: Bool) {
        self.isFavorite = favorite
        animationImageView?.removeFromSuperview()
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
            tintColor = config.notFavoriteTintColor
        }
    }
    
}

extension FavoriteButton {
    
    struct Config {
        
        static let barButton = Config(
            favoriteImage: R.image.market_favorite_solid()!
                .withRenderingMode(.alwaysTemplate),
            notFavoriteImage: R.image.market_favorite_hollow()!
                .withRenderingMode(.alwaysTemplate),
            notFavoriteTintColor: R.color.icon_tint()!,
            animationImage: {
                if let data = try? Data(contentsOf: R.file.favorite_largePng()!) {
                    SDAnimatedImage(data: data)
                } else {
                    nil
                }
            }(),
            animationSize: CGSize(width: 44, height: 44),
            duration: 1.1
        )
        
        static let listCell = Config(
            favoriteImage: R.image.market_favorited()!
                .withRenderingMode(.alwaysTemplate),
            notFavoriteImage: R.image.market_unfavorited()!
                .withRenderingMode(.alwaysTemplate),
            notFavoriteTintColor: R.color.text_tertiary()!,
            animationImage: {
                if let data = try? Data(contentsOf: R.file.favorite_mediumPng()!) {
                    SDAnimatedImage(data: data)
                } else {
                    nil
                }
            }(),
            animationSize: CGSize(width: 20, height: 20),
            duration: 1.1
        )
        
        let favoriteImage: UIImage
        let notFavoriteImage: UIImage
        let notFavoriteTintColor: UIColor
        let animationImage: SDAnimatedImage?
        let animationSize: CGSize
        let duration: TimeInterval
        
    }
    
}
