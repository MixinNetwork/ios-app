import UIKit
import AVFoundation
import Photos

final class GalleryVideoItemViewController: GalleryItemViewController, GalleryAnimatable {
    
    static var currentPipController: GalleryVideoItemViewController?
    
    private let videoView = GalleryVideoView()
    
    private var panRecognizer: UIPanGestureRecognizer!
    private var tapRecognizer: UITapGestureRecognizer!
    private var itemStatusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var sliderObserver: Any?
    private var timeLabelObserver: Any?
    private var isSeeking = false
    private var rateBeforeSeeking: Float?
    private var playerDidReachEnd = false
    private var playerDidFailedToPlay = false
    private var isPipMode = false
    
    var isPlayable: Bool {
        if let item = item {
            return item.mediaStatus == .DONE
                || item.mediaStatus == .READ
                || item.category == .live
        } else {
            return false
        }
    }
    
    var controlView: GalleryVideoControlView {
        return videoView.controlView
    }
    
    override var image: UIImage? {
        return videoView.coverImageView.image
    }
    
    override var isDownloadingAttachment: Bool {
        guard let item = item else {
            return false
        }
        let jobId = VideoDownloadJob.jobId(messageId: item.messageId)
        return ConcurrentJobQueue.shared.isExistJob(jodId: jobId)
    }
    
    override var shouldDownloadAutomatically: Bool {
        guard item?.category == .video else {
            return false
        }
        switch CommonUserDefault.shared.autoDownloadVideos {
        case .wifiAndCellular:
            return true
        case .wifi:
            return NetworkManager.shared.isReachableOnWiFi
        case .never:
            return false
        }
    }
    
    override var isFocused: Bool {
        didSet {
            if !isFocused {
                player.pause()
                if isPlayable {
                    controlView.set(playControlsHidden: false, otherControlsHidden: true, animated: false)
                }
            }
        }
    }
    
    private var player: AVPlayer {
        return videoView.player
    }
    
    private var videoRatio: CGFloat {
        guard let item = item else {
            return 1
        }
        return item.size.width / item.size.height
    }
    
    private var playerItemDuration: CMTime {
        if let item = player.currentItem, item.status == .readyToPlay {
            return item.duration
        } else {
            return .invalid
        }
    }
    
    deinit {
        removeAllObservers()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        controlView.pipButton.addTarget(self, action: #selector(pipAction), for: .touchUpInside)
        controlView.closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)
        controlView.reloadButton.addTarget(self, action: #selector(reloadAction(_:)), for: .touchUpInside)
        controlView.playButton.addTarget(self, action: #selector(playAction(_:)), for: .touchUpInside)
        controlView.pauseButton.addTarget(self, action: #selector(pauseAction(_:)), for: .touchUpInside)
        
        let slider = controlView.slider!
        slider.addTarget(self, action: #selector(beginScrubbingAction(_:)), for: .touchDown)
        slider.addTarget(self, action: #selector(scrubAction(_:)), for: .valueChanged)
        for event: UIControl.Event in [.touchCancel, .touchUpInside, .touchUpOutside] {
            slider.addTarget(self, action: #selector(endScrubbingAction(_:)), for: event)
        }
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        panRecognizer.delegate = self
        videoView.addGestureRecognizer(panRecognizer)
        
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        videoView.addGestureRecognizer(tapRecognizer)
        
        view.insertSubview(videoView, at: 0)
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView.frame = view.bounds
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        isPipMode = false
        controlView.style.remove(.loading)
        controlView.playControlStyle = .play
        controlView.set(playControlsHidden: true, otherControlsHidden: true, animated: false)
        videoView.coverImageView.sd_cancelCurrentImageLoad()
        videoView.coverImageView.image = nil
        videoView.bringCoverToFront()
        player.replaceCurrentItem(with: nil)
    }
    
    override func beginDownload() {
        guard let item = item, item.category == .video else {
            return
        }
        let job = VideoDownloadJob(messageId: item.messageId,
                                   mediaMimeType: item.mediaMimeType)
        ConcurrentJobQueue.shared.addJob(job: job)
        layout(mediaStatus: .PENDING)
    }
    
    override func cancelDownload() {
        guard let item = item else {
            return
        }
        let jobId = VideoDownloadJob.jobId(messageId: item.messageId)
        ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        layout(mediaStatus: .CANCELED)
    }
    
    override func set(thumbnail: GalleryItem.Thumbnail) {
        switch thumbnail {
        case .image(let image):
            videoView.coverImageView.image = image
        case .url(let url):
            videoView.coverImageView.sd_setImage(with: url, placeholderImage: nil, context: localImageContext)
        case .none:
            break
        }
    }
    
    override func load(item: GalleryItem?) {
        super.load(item: item)
        updateControlView()
        updateSliderPosition(time: .zero)
        guard let item = item else {
            return
        }
        videoView.videoRatio = item.size.width / item.size.height
        videoView.layoutFullsized()
        if item.category == .video {
            controlView.style.remove(.liveStream)
        } else if item.category == .live {
            controlView.style.insert(.liveStream)
        }
        if let url = item.url, item.category == .video {
            loadAssetIfPlayable(url: url, playAfterLoaded: false)
        }
    }
    
    override func saveToLibrary() {
        guard let url = item?.url else {
            showAutoHiddenHud(style: .error, text: Localized.CAMERA_SAVE_VIDEO_FAILED)
            return
        }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }, completionHandler: { (success, error) in
            DispatchQueue.main.async {
                if success {
                    showAutoHiddenHud(style: .notification, text: Localized.CAMERA_SAVE_VIDEO_SUCCESS)
                } else {
                    showAutoHiddenHud(style: .error, text: Localized.CAMERA_SAVE_VIDEO_FAILED)
                }
            }
        })
    }
    
    override func willBeginInteractiveDismissal() {
        super.willBeginInteractiveDismissal()
        controlView.set(playControlsHidden: true, otherControlsHidden: true, animated: true)
    }
    
    override func didCancelInteractiveDismissal() {
        super.didCancelInteractiveDismissal()
        if player.timeControlStatus != .playing {
            controlView.set(playControlsHidden: false, otherControlsHidden: true, animated: true)
        }
    }
    
    @objc func pipAction() {
        isPipMode.toggle()
        if isPipMode {
            controlView.pipButton.setImage(R.image.ic_video_pip(), for: .normal)
            videoView.removeFromSuperview()
            GalleryVideoItemViewController.currentPipController = self
            UIApplication.homeContainerViewController?.view.addSubview(videoView)
            galleryViewController?.dismissForPip()
        } else {
            controlView.pipButton.setImage(R.image.ic_video_fullsize(), for: .normal)
            GalleryVideoItemViewController.currentPipController = nil
            galleryViewController?.show(itemViewController: self)
        }
        if player.timeControlStatus == .playing {
            controlView.set(playControlsHidden: true, otherControlsHidden: true, animated: false)
        }
        let isPipMode = self.isPipMode
        animate(animations: {
            if isPipMode {
                self.videoView.layoutPip()
            } else {
                self.videoView.layoutFullsized()
            }
        }, completion: {
            if !isPipMode {
                self.videoView.removeFromSuperview()
                self.view.insertSubview(self.videoView, at: 0)
            }
        })
    }
    
    @objc func closeAction() {
        player.pause()
        if isPipMode {
            isPipMode = false
            videoView.removeFromSuperview()
            if let view = view {
                view.insertSubview(videoView, at: 0)
                videoView.frame = view.bounds
                videoView.layoutFullsized()
            }
            GalleryVideoItemViewController.currentPipController = nil
        } else {
            galleryViewController?.dismiss(transitionViewInitialOffsetY: 0)
        }
    }
    
    @objc func reloadAction(_ sender: Any) {
        guard let url = item?.url else {
            return
        }
        playerDidReachEnd = false
        playerDidFailedToPlay = false
        loadAssetIfPlayable(url: url, playAfterLoaded: true)
    }
    
    @objc func playAction(_ sender: Any) {
        guard let item = item else {
            return
        }
        playerDidFailedToPlay = false
        controlView.set(playControlsHidden: true, otherControlsHidden: true, animated: false)
        if item.category == .video || player.currentItem != nil {
            AudioManager.shared.pause()
            if playerDidReachEnd {
                playerDidReachEnd = false
                player.seek(to: .zero)
            }
            addTimeObservers()
            player.play()
        } else if let url = item.url {
            loadAssetIfPlayable(url: url, playAfterLoaded: true)
        }
    }
    
    @objc func pauseAction(_ sender: Any) {
        removeTimeObservers()
        player.pause()
    }
    
    @objc func panAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: view)
        case .changed:
            let translation = recognizer.translation(in: view)
            videoView.center = CGPoint(x: videoView.center.x + translation.x,
                                       y: videoView.center.y + translation.y)
            recognizer.setTranslation(.zero, in: view)
        case .ended, .cancelled:
            let velocity = recognizer.velocity(in: view).x
            videoView.stickToSuperviewEdge(horizontalVelocity: velocity)
        default:
            break
        }
    }
    
    @objc func tapAction(_ recognizer: UITapGestureRecognizer) {
        if player.timeControlStatus == .playing {
            let isShowingPlayControl = controlView.playControlWrapperView.alpha > 0
            controlView.set(playControlsHidden: isShowingPlayControl,
                            otherControlsHidden: isShowingPlayControl,
                            animated: true)
        } else if controlView.style.contains(.loading) {
            let isShowingVisualControl = controlView.visualControlWrapperView.alpha > 0
            controlView.set(playControlsHidden: true,
                            otherControlsHidden: isShowingVisualControl,
                            animated: true)
        }
    }
    
    @objc func playerItemDidReachEnd(_ notification: Notification) {
        guard let item = item else {
            return
        }
        playerDidReachEnd = true
        if item.category == .video {
            controlView.playControlStyle = .play
        } else if item.category == .live {
            controlView.playControlStyle = .reload
        }
        controlView.set(playControlsHidden: false, otherControlsHidden: false, animated: true)
        removeTimeObservers()
    }
    
    @objc func playerItemFailedToPlayToEndTime(_ notification: Notification) {
        playerDidFailedToPlay = true
        controlView.playControlStyle = .reload
        controlView.style.remove(.loading)
        controlView.set(playControlsHidden: false, otherControlsHidden: false, animated: true)
        removeTimeObservers()
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
    
    private func loadAssetIfPlayable(url: URL, playAfterLoaded: Bool) {
        let asset = AVURLAsset(url: url)
        let playableKey = #keyPath(AVAsset.isPlayable)
        var error: NSError?
        
        if asset.statusOfValue(forKey: playableKey, error: &error) == .loaded {
            load(playableAsset: asset, playAfterLoaded: playAfterLoaded)
        } else if let error = error {
            UIApplication.traceError(error)
            controlView.playControlStyle = .reload
            controlView.activityIndicatorView.isAnimating = false
        } else {
            asset.loadValuesAsynchronously(forKeys: [playableKey]) {
                guard asset.statusOfValue(forKey: playableKey, error: &error) == .loaded else {
                    if let error = error {
                        UIApplication.traceError(error)
                    }
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let weakSelf = self, weakSelf.item?.url == url else {
                        return
                    }
                    weakSelf.load(playableAsset: asset, playAfterLoaded: playAfterLoaded)
                }
            }
        }
    }
    
    private func load(playableAsset asset: AVURLAsset, playAfterLoaded: Bool) {
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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemFailedToPlayToEndTime(_:)),
                                               name: .AVPlayerItemFailedToPlayToEndTime,
                                               object: item)
        
        rateObserver = player.observe(\.timeControlStatus, changeHandler: { [weak self] (player, _) in
            self?.updateControlView()
            self?.bringPlayerToFrontIfPlaying()
        })
        
        player.replaceCurrentItem(with: item)
        if playAfterLoaded {
            AudioManager.shared.pause()
            player.play()
        }
    }
    
    private func updateControlView() {
        switch player.timeControlStatus {
        case .playing:
            controlView.playControlStyle = .pause
            controlView.style.remove(.loading)
        case .paused:
            if item?.category == .video || (!playerDidReachEnd && !playerDidFailedToPlay) {
                controlView.playControlStyle = .play
            }
            controlView.set(playControlsHidden: false, otherControlsHidden: false, animated: true)
        case .waitingToPlayAtSpecifiedRate:
            if item?.category == .live {
                controlView.style.insert(.loading)
            }
        @unknown default:
            controlView.set(playControlsHidden: false, otherControlsHidden: false, animated: true)
        }
    }
    
    private func bringPlayerToFrontIfPlaying() {
        guard player.timeControlStatus == .playing else {
            return
        }
        videoView.bringPlayerToFront()
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
    
    private func removeAllObservers() {
        removeTimeObservers()
        itemStatusObserver?.invalidate()
        rateObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
}

extension GalleryVideoItemViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return isPipMode
    }
    
}
