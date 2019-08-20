import UIKit
import AVFoundation

final class GalleryVideoView: UIView, GalleryAnimatable {
    
    let contentView = UIView()
    let coverImageView = UIImageView()
    let player = AVPlayer()
    let playerView = PlayerView()
    let controlView = R.nib.galleryVideoControlView(owner: nil)!
    
    var coverRatio: CGFloat = 1
    var videoRatio: CGFloat = 1
    var isPipMode = false {
        didSet {
            if isPipMode {
                controlView.style.insert(.pip)
            } else {
                controlView.style.remove(.pip)
            }
            setNeedsLayout()
            layoutIfNeeded()
            updateCornerRadiusAndShadow()
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
    
    convenience init() {
        self.init(frame: CGRect(x: 0, y: 0, width: 375, height: 240))
        backgroundColor = .clear
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.bounds.size = CGSize(width: bounds.width , height: ceil(bounds.width / videoRatio))
        contentView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        playerView.frame = contentView.bounds
        coverImageView.bounds.size = CGSize(width: contentView.bounds.width,
                                            height: ceil(contentView.bounds.width / coverRatio))
        coverImageView.center = CGPoint(x: contentView.bounds.midX,
                                        y: contentView.bounds.midY)
        layoutControlView()
    }
    
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        layoutControlView()
    }
    
    private func layoutControlView() {
        if isPipMode || safeAreaInsets.top <= 20 {
            controlView.frame = bounds
        } else {
            controlView.frame = bounds.inset(by: safeAreaInsets)
        }
    }
    
    private func updateCornerRadiusAndShadow() {
        let fromCornerRadius = contentView.layer.cornerRadius
        let toCornerRadius: CGFloat = isPipMode ? 6 : 0
        contentView.layer.cornerRadius = toCornerRadius
        let cornerRadiusAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.cornerRadius))
        cornerRadiusAnimation.fromValue = fromCornerRadius
        cornerRadiusAnimation.toValue = toCornerRadius
        cornerRadiusAnimation.duration = animationDuration
        
        let toShadowOpacity: Float = isPipMode ? 0.14 : 0
        let fromShadowOpacity = layer.shadowOpacity
        layer.shadowOpacity = toShadowOpacity
        let shadowOpacityAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.shadowOpacity))
        shadowOpacityAnimation.fromValue = fromShadowOpacity
        shadowOpacityAnimation.toValue = toShadowOpacity
        shadowOpacityAnimation.duration = animationDuration
        
        contentView.layer.add(cornerRadiusAnimation, forKey: cornerRadiusAnimation.keyPath)
        layer.add(shadowOpacityAnimation, forKey: shadowOpacityAnimation.keyPath)
    }
    
    private func prepare() {
        // TODO: Use explicit shadowPath
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 4
        layer.shadowOpacity = 0
        
        contentView.frame = bounds
        contentView.clipsToBounds = true
        contentView.backgroundColor = .clear
        
        coverImageView.contentMode = .scaleAspectFill
        
        playerView.backgroundColor = .clear
        playerView.layer.videoGravity = .resizeAspect
        playerView.layer.player = player
        
        contentView.addSubview(coverImageView)
        contentView.addSubview(playerView)
        addSubview(contentView)
        
        controlView.frame = bounds
        addSubview(controlView)
    }
    
}
