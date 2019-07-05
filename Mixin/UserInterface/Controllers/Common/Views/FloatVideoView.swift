import UIKit
import AVFoundation

final class FloatVideoView: UIView {
    
    let backgroundView = UIView()
    let player = AVPlayer()
    let playerView = PlayerView()
    let controlView = R.nib.floatVideoControlView(owner: nil)!
    
    var zoomsOnTouch = false
    
    private let minLayerHeight: CGFloat = 240
    
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
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard zoomsOnTouch else {
            return
        }
        UIView.animate(withDuration: 0.2) {
            self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard self.transform != .identity else {
            return
        }
        UIView.animate(withDuration: 0.2) {
            self.transform = .identity
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard self.transform != .identity else {
            return
        }
        UIView.animate(withDuration: 0.2) {
            self.transform = .identity
        }
    }
    
    func stickToWindowEdge() {
        guard let window = window else {
            return
        }
        let x: CGFloat
        if center.x > window.bounds.midX {
            x = window.bounds.width - window.layoutMargins.right - frame.size.width / 2
        } else {
            x = window.layoutMargins.left + frame.size.width / 2
        }
        let y: CGFloat = {
            let halfHeight = frame.size.height / 2
            let minY = window.layoutMargins.top + halfHeight
            let maxY = window.bounds.height - window.layoutMargins.bottom - halfHeight
            return min(maxY, max(minY, center.y))
        }()
        UIView.animate(withDuration: 0.3) {
            self.center = CGPoint(x: x, y: y)
        }
    }
    
    func layoutFullsized(on window: UIWindow, videoRatio: CGFloat) {
        let layerWidth = window.bounds.width - window.safeAreaInsets.horizontal
        let maxLayerHeight = window.bounds.height - window.safeAreaInsets.vertical
        let rawHeight = layerWidth / videoRatio
        let layerHeight = min(maxLayerHeight, max(minLayerHeight, rawHeight))
        playerView.frame = CGRect(x: window.safeAreaInsets.left,
                                  y: window.safeAreaInsets.top,
                                  width: layerWidth,
                                  height: layerHeight)
        set(roundedCorner: false)
        
        let viewHeight: CGFloat
        if window.bounds.height - window.safeAreaInsets.top - layerHeight > window.safeAreaInsets.bottom {
            viewHeight = window.safeAreaInsets.top + layerHeight
        } else {
            viewHeight = window.bounds.height
        }
        frame = CGRect(x: 0, y: 0, width: window.bounds.width, height: viewHeight)
        backgroundView.frame = bounds
        
        controlView.frame = playerView.frame
        controlView.reloadButton.transform = .identity
        controlView.activityIndicatorView.transform = .identity
        controlView.setNeedsLayout()
        controlView.layoutIfNeeded()
    }
    
    func layoutPip(on window: UIWindow, videoRatio: CGFloat) {
        let size: CGSize
        if videoRatio > 0.9 {
            let width = window.bounds.width / 2
            size = CGSize(width: width, height: width / videoRatio)
        } else {
            let height = window.bounds.height / 3
            size = CGSize(width: height * videoRatio, height: height)
        }
        frame.size = size
        center = CGPoint(x: window.bounds.width - window.layoutMargins.right - size.width / 2,
                         y: window.safeAreaInsets.top + size.height / 2)
        backgroundView.frame = bounds
        playerView.frame = bounds
        set(roundedCorner: true)
        
        controlView.frame = bounds
        controlView.reloadButton.transform = CGAffineTransform(scaleX: 0.54, y: 0.54)
        controlView.activityIndicatorView.transform = CGAffineTransform(scaleX: 0.54, y: 0.54)
        controlView.setNeedsLayout()
        controlView.layoutIfNeeded()
    }
    
    private func set(roundedCorner: Bool) {
        backgroundView.layer.cornerRadius = roundedCorner ? 8 : 0
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.35
        layer.shadowPath = UIBezierPath(roundedRect: layer.bounds, cornerRadius: layer.cornerRadius).cgPath
    }
    
    private func prepare() {
        backgroundView.clipsToBounds = true
        backgroundView.backgroundColor = .black
        addSubview(backgroundView)
        playerView.layer.player = player
        playerView.layer.masksToBounds = true
        backgroundView.addSubview(playerView)
        backgroundView.addSubview(controlView)
    }
    
}
