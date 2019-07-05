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
    private var sliderObserver: Any?
    private var timeLabelObserver: Any?
    private var isSeeking = false
    private var rateBeforeSeeking: Float?
    private var itemStatusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var seekToZeroBeforePlaying = false
    
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
        controlView.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
        controlView.playButton.addTarget(self, action: #selector(playAction(_:)), for: .touchUpInside)
        
        let slider = controlView.slider!
        slider.addTarget(self, action: #selector(beginScrubbingAction(_:)), for: .touchDown)
        slider.addTarget(self, action: #selector(scrubAction(_:)), for: .valueChanged)
        for event: UIControl.Event in [.touchCancel, .touchUpInside, .touchUpOutside] {
            slider.addTarget(self, action: #selector(endScrubbingAction(_:)), for: event)
        }
        
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
        view.layoutFullsized(on: window, videoRatio: videoRatio)
        updateSliderPosition(time: .zero)
        
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
    
    @objc func pauseAction(_ sender: Any) {
        player.pause()
    }
    
    @objc func playAction(_ sender: Any) {
        if seekToZeroBeforePlaying {
            player.seek(to: .zero)
            seekToZeroBeforePlaying = false
        }
        player.play()
    }
    
    @objc func beginScrubbingAction(_ sender: Any) {
        rateBeforeSeeking = player.rate
        player.rate = 0
        removeTimeObservers()
    }
    
    @objc func scrubAction(_ sender: Any) {
        guard !isSeeking else {
            return
        }
        isSeeking = true
        guard playerItemDuration.isValid else {
            return
        }
        let duration = CMTimeGetSeconds(playerItemDuration)
        guard duration.isFinite else {
            return
        }
        let minValue = controlView.slider.minimumValue
        let maxValue = controlView.slider.maximumValue
        let value = controlView.slider.value
        let time = duration * Double(value - minValue) / Double(maxValue - minValue)
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime) { [weak self] (_) in
            DispatchQueue.main.async {
                self?.isSeeking = false
            }
        }
    }
    
    @objc func endScrubbingAction(_ sender: Any) {
        if sliderObserver == nil && timeLabelObserver == nil {
            addTimeObservers()
        }
        if let rate = rateBeforeSeeking {
            player.rate = rate
        }
        rateBeforeSeeking = nil
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
        seekToZeroBeforePlaying = true
    }
    
    private func play(asset: AVURLAsset) {
        guard asset.isPlayable else {
            // TODO: UI Update
            return
        }
        removeAllObservers()
        seekToZeroBeforePlaying = false
        
        let item = AVPlayerItem(asset: asset)
        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] (item, change) in
            // Known issue: https://bugs.swift.org/browse/SR-5872
            // 'change' are always nil here
            self?.update(playerItemStatus: item.status)
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidReachEnd(_:)),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: item)
        
        rateObserver = player.observe(\.rate, changeHandler: { [weak self] (player, _) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.updatePlayPauseButton(isPlaying: player.rate > 0)
        })
        
        player.replaceCurrentItem(with: item)
        player.play()
    }
    
    private func update(playerItemStatus status: AVPlayerItem.Status) {
        switch status {
        case .unknown:
            controlView.slider.isEnabled = false
        case .readyToPlay:
            addTimeObservers()
            controlView.slider.isEnabled = true
        case .failed:
            break
        }
    }
    
    private func updateSliderPosition(time: CMTime) {
        guard playerItemDuration.isValid else {
            return
        }
        let duration = CMTimeGetSeconds(playerItemDuration)
        guard duration.isFinite else {
            return
        }
        let time = CMTimeGetSeconds(time)
        let slider = controlView.slider!
        let maxSliderValue = slider.maximumValue
        let minSliderValue = slider.minimumValue
        let sliderValue = Float(Double(maxSliderValue - minSliderValue) * time / duration + Double(minSliderValue))
        slider.setValue(sliderValue, animated: false)
    }
    
    private func updateTimeLabel(time: CMTime) {
        guard playerItemDuration.isValid else {
            return
        }
        let duration = CMTimeGetSeconds(playerItemDuration)
        guard duration.isFinite else {
            return
        }
        let time = CMTimeGetSeconds(time)
        
        controlView.playedTimeLabel.text = mediaDurationFormatter.string(from: time)
        controlView.remainingTimeLabel.text = mediaDurationFormatter.string(from: duration - time)
    }
    
    private func updatePlayPauseButton(isPlaying: Bool) {
        controlView.playButton.isHidden = isPlaying
        controlView.pauseButton.isHidden = !isPlaying
    }
    
    private func removeAllObservers() {
        removeTimeObservers()
        itemStatusObserver?.invalidate()
        rateObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func addTimeObservers() {
        let timescale = CMTimeScale(600)
        
        let sliderInterval = CMTime(seconds: 0.1, preferredTimescale: timescale)
        sliderObserver = player.addPeriodicTimeObserver(forInterval: sliderInterval, queue: .main, using: { [weak self] (time) in
            guard let weakSelf = self, weakSelf.player.rate > 0 else {
                return
            }
            weakSelf.updateSliderPosition(time: time)
        })
        
        let timeLabelInterval = CMTime(seconds: 1, preferredTimescale: timescale)
        timeLabelObserver = player.addPeriodicTimeObserver(forInterval: timeLabelInterval, queue: .main, using: { [weak self] (time) in
            guard let weakSelf = self, weakSelf.player.rate > 0 else {
                return
            }
            weakSelf.updateTimeLabel(time: time)
        })
    }
    
    private func removeTimeObservers() {
        [sliderObserver, timeLabelObserver]
            .compactMap({ $0 })
            .forEach(player.removeTimeObserver)
        sliderObserver = nil
        timeLabelObserver = nil
    }
    
}

extension FloatVideoController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return isPipMode
    }
    
}
