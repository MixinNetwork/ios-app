import UIKit
import AVFoundation

final class GalleryVideoView: UIView, GalleryAnimatable {
    
    let backgroundView = UIView()
    let coverImageView = UIImageView()
    let player = AVPlayer()
    let playerView = PlayerView()
    let controlView = R.nib.galleryVideoControlView(owner: nil)!
    
    var videoRatio: CGFloat = 1
    
    private let stickToEdgeVelocityLimit: CGFloat = 800
    private let pipModeMinInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
    private let pipModeDefaultTopMargin: CGFloat = 61
    
    private var isPipMode = false
    
    private var adjustedSafeAreaInsets: UIEdgeInsets {
        let insets = superview?.safeAreaInsets ?? .zero
        return UIEdgeInsets(top: max(20, insets.top),
                            left: insets.left,
                            bottom: max(5, insets.bottom),
                            right: insets.right)
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
        backgroundView.frame = bounds
        for view in [coverImageView, playerView] {
            let height = bounds.width / videoRatio
            view.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: height)
            view.center = CGPoint(x: backgroundView.bounds.midX, y: backgroundView.bounds.midY)
        }
        layoutControlView()
    }
    
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        layoutControlView()
    }
    
    func stickToSuperviewEdge(horizontalVelocity: CGFloat) {
        guard let superview = superview else {
            return
        }
        let x: CGFloat
        let shouldStickToRightEdge = center.x > superview.bounds.midX && horizontalVelocity > -stickToEdgeVelocityLimit
            || center.x < superview.bounds.midX && horizontalVelocity > stickToEdgeVelocityLimit
        if shouldStickToRightEdge {
            x = superview.bounds.width - pipModeMinInsets.right - frame.size.width / 2
        } else {
            x = pipModeMinInsets.left + frame.size.width / 2
        }
        let y: CGFloat = {
            let halfHeight = frame.size.height / 2
            let minY = adjustedSafeAreaInsets.top + pipModeMinInsets.top + halfHeight
            let maxY = superview.bounds.height - adjustedSafeAreaInsets.bottom - pipModeMinInsets.bottom - halfHeight
            return min(maxY, max(minY, center.y))
        }()
        UIView.animate(withDuration: 0.3) {
            self.center = CGPoint(x: x, y: y)
        }
    }
    
    func layoutFullsized() {
        isPipMode = false
        controlView.style.remove(.pip)
        if let superview = superview {
            frame = superview.bounds
        }
        controlView.reloadButton.transform = .identity
        controlView.activityIndicatorView.transform = .identity
        setNeedsLayout()
        layoutIfNeeded()
        updateCornerRadiusAndShadow()
    }
    
    func layoutPip() {
        isPipMode = true
        controlView.style.insert(.pip)
        if let superview = superview {
            let size: CGSize
            if videoRatio > 0.9 {
                let width = superview.bounds.width * (2 / 3)
                size = CGSize(width: width, height: width / videoRatio)
            } else {
                let height = superview.bounds.height / 3
                size = CGSize(width: height * videoRatio, height: height)
            }
            frame.size = size
            center = CGPoint(x: superview.bounds.width - pipModeMinInsets.right - size.width / 2,
                             y: adjustedSafeAreaInsets.top + pipModeDefaultTopMargin + size.height / 2)
        }
        setNeedsLayout()
        layoutIfNeeded()
        updateCornerRadiusAndShadow()
    }
    
    private func layoutControlView() {
        if isPipMode {
            controlView.frame = backgroundView.bounds
        } else {
            controlView.frame = backgroundView.bounds.inset(by: safeAreaInsets)
        }
    }
    
    private func updateCornerRadiusAndShadow() {
        let fromCornerRadius = backgroundView.layer.cornerRadius
        let toCornerRadius: CGFloat = isPipMode ? 8 : 0
        backgroundView.layer.cornerRadius = toCornerRadius
        let cornerRadiusAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.cornerRadius))
        cornerRadiusAnimation.fromValue = fromCornerRadius
        cornerRadiusAnimation.toValue = toCornerRadius
        cornerRadiusAnimation.duration = animationDuration
        
        let toShadowOpacity: Float = isPipMode ? 0.35 : 0
        let fromShadowOpacity = layer.shadowOpacity
        layer.shadowOpacity = toShadowOpacity
        let shadowOpacityAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.shadowOpacity))
        shadowOpacityAnimation.fromValue = fromShadowOpacity
        shadowOpacityAnimation.toValue = toShadowOpacity
        shadowOpacityAnimation.duration = animationDuration
        
        backgroundView.layer.add(cornerRadiusAnimation, forKey: cornerRadiusAnimation.keyPath)
        layer.add(shadowOpacityAnimation, forKey: shadowOpacityAnimation.keyPath)
    }
    
    private func prepare() {
        // TODO: Use explicit shadowPath
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 8
        layer.shadowOpacity = 0
        
        backgroundView.frame = bounds
        backgroundView.clipsToBounds = true
        backgroundView.backgroundColor = .clear
        
        coverImageView.contentMode = .scaleAspectFit
        
        playerView.layer.player = player
        
        backgroundView.addSubview(coverImageView)
        backgroundView.addSubview(playerView)
        backgroundView.addSubview(controlView)
        addSubview(backgroundView)
    }
    
}
