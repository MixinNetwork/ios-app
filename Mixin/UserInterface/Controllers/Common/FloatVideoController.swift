import UIKit
import AVFoundation

final class FloatVideoController: NSObject {
    
    let view = FloatVideoView()
    
    private let timeObserverInterval: Double = 1
    private let animationDuration: TimeInterval = 0.3
    
    private var videoRatio: CGFloat = 1
    private var panRecognizer: UIPanGestureRecognizer!
    private var isPipMode = false {
        didSet {
            view.zoomsOnTouch = isPipMode
        }
    }
    
    private var url: URL?
    private var itemStatusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    
    private var controlView: FloatVideoControlView {
        return view.controlView
    }
    
    private var player: AVPlayer {
        return view.player
    }
    
    private var playerItemDuration: CMTime {
        if let item = player.currentItem, item.status == .readyToPlay {
            return item.duration
        } else {
            return .invalid
        }
    }
    
    override init() {
        super.init()
        
        controlView.pipButton.addTarget(self, action: #selector(pipAction(_:)), for: .touchUpInside)
        controlView.closeButton.addTarget(self, action: #selector(closeAction(_:)), for: .touchUpInside)
        controlView.reloadButton.addTarget(self, action: #selector(reloadAction(_:)), for: .touchUpInside)
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        panRecognizer.cancelsTouchesInView = false
        panRecognizer.delegate = self
        view.addGestureRecognizer(panRecognizer)
    }
    
    deinit {
        removeAllObservers()
    }
    
    func play(url: URL, videoRatio: CGFloat) {
        guard let window = UIApplication.shared.keyWindow else {
            return
        }
        self.url = url
        self.videoRatio = videoRatio
        isPipMode = false
        controlView.set(reloadButtonHidden: true, activityIndicatorHidden: false)
        view.layoutFullsized(on: window, videoRatio: videoRatio)
        
        if view.window != window {
            view.removeFromSuperview()
            window.addSubview(view)
        }
        
        let asset = AVURLAsset(url: url)
        
        let playableKey = "playable"
        let keys = [playableKey]
        var error: NSError?
        
        func report(error: NSError?) {
            let userinfo: [String : Any] = ["error": error as Any, "url": url]
            UIApplication.trackError(#file, action: #function, userInfo: userinfo)
        }
        
        if asset.statusOfValue(forKey: playableKey, error: &error) == .loaded {
            play(asset: asset)
        } else if let error = error {
            report(error: error)
            controlView.set(reloadButtonHidden: false, activityIndicatorHidden: true)
        } else {
            asset.loadValuesAsynchronously(forKeys: keys) {
                guard asset.statusOfValue(forKey: playableKey, error: &error) == .loaded else {
                    report(error: error)
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let weakSelf = self, weakSelf.url == asset.url else {
                        return
                    }
                    weakSelf.play(asset: asset)
                }
            }
        }
    }
    
    @objc func pipAction(_ sender: Any) {
        isPipMode.toggle()
        guard let window = view.window else {
            return
        }
        let ratio = self.videoRatio
        let layout = isPipMode ? view.layoutPip : view.layoutFullsized
        UIView.animate(withDuration: animationDuration) {
            layout(window, ratio)
        }
    }
    
    @objc func closeAction(_ sender: Any) {
        player.pause()
        view.removeFromSuperview()
    }
    
    @objc func reloadAction(_ sender: Any) {
        guard let url = url else {
            return
        }
        play(url: url, videoRatio: videoRatio)
    }
    
    @objc func panAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: view)
        case .changed:
            let translation = recognizer.translation(in: view)
            view.center = CGPoint(x: view.center.x + translation.x,
                                  y: view.center.y + translation.y)
            recognizer.setTranslation(.zero, in: view)
        case .ended:
            view.stickToWindowEdge()
        default:
            break
        }
    }
    
    @objc func playerItemDidReachEnd(_ notification: Notification) {
        
    }
    
    private func play(asset: AVURLAsset) {
        guard asset.isPlayable else {
            // TODO: UI Update
            return
        }
        removeAllObservers()
        
        let item = AVPlayerItem(asset: asset)
        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] (item, change) in
            // Known issue: https://bugs.swift.org/browse/SR-5872
            // 'change' are always nil here
            self?.updateControlView()
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidReachEnd(_:)),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: item)
        
        rateObserver = player.observe(\.timeControlStatus, changeHandler: { [weak self] (player, _) in
            self?.updateControlView()
        })
        
        player.replaceCurrentItem(with: item)
        player.play()
    }
    
    private func updateControlView() {
        if player.timeControlStatus == .playing {
            controlView.set(reloadButtonHidden: true, activityIndicatorHidden: true)
        } else {
            if let item = player.currentItem {
                switch item.status {
                case .readyToPlay:
                    controlView.set(reloadButtonHidden: true, activityIndicatorHidden: false)
                case .unknown:
                    controlView.set(reloadButtonHidden: true, activityIndicatorHidden: false)
                case .failed:
                    fallthrough
                @unknown default:
                    controlView.set(reloadButtonHidden: false, activityIndicatorHidden: true)
                }
            } else {
                controlView.set(reloadButtonHidden: false, activityIndicatorHidden: true)
            }
        }
    }
    
    private func removeAllObservers() {
        itemStatusObserver?.invalidate()
        rateObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
}

extension FloatVideoController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return isPipMode
    }
    
}
