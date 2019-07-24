import UIKit
import AVFoundation

final class GalleryVideoView: UIView {
    
    let backgroundView = UIView()
    let coverImageView = UIImageView()
    let player = AVPlayer()
    let playerView = PlayerView()
    let controlView = R.nib.galleryVideoControlView(owner: nil)!
    
    var isPipMode = false {
        didSet {
            if isPipMode {
                controlView.style.insert(.pip)
            } else {
                controlView.style.remove(.pip)
            }
            setNeedsLayout()
        }
    }
    
    var roundCorners = false {
        didSet {
            let cornerRadius: CGFloat = roundCorners ? 8 : 0
            
            let fromCornerRadius = backgroundView.layer.cornerRadius
            backgroundView.layer.cornerRadius = cornerRadius
            let cornerRadiusAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.cornerRadius))
            cornerRadiusAnimation.fromValue = fromCornerRadius
            cornerRadiusAnimation.toValue = cornerRadius
            cornerRadiusAnimation.duration = 2
            
            backgroundView.layer.add(cornerRadiusAnimation, forKey: cornerRadiusAnimation.keyPath)
        }
    }
    
    private let minLayerHeight: CGFloat = 240
    
    private var videoRatio: CGFloat = 1
    
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
    
    func stickToWindowEdge() {
        guard let superview = superview else {
            return
        }
        let x: CGFloat
        if center.x > superview.bounds.midX {
            x = superview.bounds.width - superview.layoutMargins.right - frame.size.width / 2
        } else {
            x = superview.layoutMargins.left + frame.size.width / 2
        }
        let y: CGFloat = {
            let halfHeight = frame.size.height / 2
            let minY = superview.layoutMargins.top + halfHeight
            let maxY = superview.bounds.height - superview.layoutMargins.bottom - halfHeight
            return min(maxY, max(minY, center.y))
        }()
        UIView.animate(withDuration: 0.3) {
            self.center = CGPoint(x: x, y: y)
        }
    }
    
    func layoutFullsized(videoRatio: CGFloat) {
        self.videoRatio = videoRatio
        guard let superview = superview else {
            return
        }
        frame = superview.bounds
        controlView.reloadButton.transform = .identity
        controlView.activityIndicatorView.transform = .identity
        setNeedsLayout()
        layoutIfNeeded()
        roundCorners = false
    }
    
    func layoutPip(videoRatio: CGFloat) {
        self.videoRatio = videoRatio
        guard let superview = superview else {
            return
        }
        
        let size: CGSize
        if videoRatio > 0.9 {
            let width = superview.bounds.width / 2
            size = CGSize(width: width, height: width / videoRatio)
        } else {
            let height = superview.bounds.height / 3
            size = CGSize(width: height * videoRatio, height: height)
        }
        frame.size = size
        center = CGPoint(x: superview.bounds.width - superview.layoutMargins.right - size.width / 2,
                         y: superview.safeAreaInsets.top + size.height / 2)
        controlView.reloadButton.transform = CGAffineTransform(scaleX: 0.54, y: 0.54)
        controlView.activityIndicatorView.transform = CGAffineTransform(scaleX: 0.54, y: 0.54)
        setNeedsLayout()
        layoutIfNeeded()
        roundCorners = true
    }
    
    private func layoutControlView() {
        if isPipMode {
            controlView.frame = backgroundView.bounds
        } else {
            controlView.frame = backgroundView.bounds.inset(by: safeAreaInsets)
        }
    }
    
    private func prepare() {
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 8
        
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
