import UIKit
import AVFoundation

final class FloatVideoController: NSObject {
    
    let view = FloatVideoView()
    
    private let sliderObserverInterval = CMTime(seconds: 0.1, preferredTimescale: nanosecondsPerSecond)
    private let timeLabelObserverInterval = CMTime(seconds: 1, preferredTimescale: nanosecondsPerSecond)
    private let animationDuration: TimeInterval = 0.3
    
    private var videoRatio: CGFloat = 1
    private var isPipMode = false
    private var panRecognizer: UIPanGestureRecognizer!
    
    private var sliderObserver: Any?
    private var timeLabelObserver: Any?
    private var isSeeking = false
    private var rateBeforeSeeking: Float = 0
    
    override init() {
        super.init()
        
        let controlView = view.controlView
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
    
    func play(url: URL, videoRatio: CGFloat) {
        guard let window = UIApplication.shared.keyWindow else {
            return
        }
        self.videoRatio = videoRatio
        view.layoutFullsized(on: window, videoRatio: videoRatio)
        if view.window != window {
            view.removeFromSuperview()
            window.addSubview(view)
        }
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        view.player.replaceCurrentItem(with: item)
        view.player.play()
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
        view.player.pause()
        view.removeFromSuperview()
    }
    
    @objc func pauseAction(_ sender: Any) {
        
    }
    
    @objc func playAction(_ sender: Any) {
        
    }
    
    @objc func beginScrubbingAction(_ sender: Any) {
        
    }
    
    @objc func scrubAction(_ sender: Any) {
        
    }
    
    @objc func endScrubbingAction(_ sender: Any) {
        
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
    
}

extension FloatVideoController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return isPipMode
    }
    
}
