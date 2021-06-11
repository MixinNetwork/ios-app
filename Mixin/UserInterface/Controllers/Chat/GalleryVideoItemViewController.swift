import UIKit
import AVKit
import Photos
import MixinServices

final class GalleryVideoItemViewController: GalleryItemViewController, GalleryAnimatable {
    
    let videoView = GalleryVideoView()
    
    private let builtInPipVideoInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
    private let builtInPipCornerRadius: CGFloat = 6
    
    private(set) var panningController: ViewPanningController?
    
    private var tapRecognizer: UITapGestureRecognizer!
    private var itemStatusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var itemPresentationSizeObserver: NSKeyValueObservation?
    private var sliderObserver: Any?
    private var timeLabelObserver: Any?
    private var isSeeking = false
    private var rateBeforeSeeking: Float?
    private var playerDidReachEnd = false
    private var playerDidFailedToPlay = false
    private var videoRatio: CGFloat = 1
    private var avPipController: AVPictureInPictureController?
    private var isBuiltInPipActive = false {
        didSet {
            panningController?.isEnabled = isBuiltInPipActive
        }
    }
    
    private var avPipPossibilityObservation: NSKeyValueObservation?
    
    var hidePlayControlAfterPlaybackBegins = false
    
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
    
    var isAvPipActive: Bool {
        avPipController?.isPictureInPictureActive ?? false
    }
    
    override var image: UIImage? {
        return videoView.coverImageView.image
    }
    
    override var isDownloadingAttachment: Bool {
        guard let item = item else {
            return false
        }
        let jobId = AttachmentDownloadJob.jobId(transcriptId: item.transcriptId, messageId: item.messageId)
        return ConcurrentJobQueue.shared.isExistJob(jodId: jobId)
    }
    
    override var shouldDownloadAutomatically: Bool {
        guard item?.category == .video else {
            return false
        }
        switch AppGroupUserDefaults.User.autoDownloadVideos {
        case .wifiAndCellular:
            return true
        case .wifi:
            return ReachabilityManger.shared.isReachableOnEthernetOrWiFi
        case .never:
            return false
        }
    }
    
    override var isFocused: Bool {
        didSet {
            guard !isFocused else {
                return
            }
            player.pause()
            if isPlayable {
                updateControlView(playControlsHidden: false, otherControlsHidden: true, animated: false)
            }
            AudioSession.shared.deactivateAsynchronously(client: self, notifyOthersOnDeactivation: false)
        }
    }
    
    override var isReusable: Bool {
        return parent == nil && UIApplication.homeContainerViewController?.pipController != self
    }
    
    override var supportedActions: Action {
        switch item?.category {
        case .video:
            return [.forward, .saveToLibrary]
        case .live:
            return [.forward]
        default:
            return []
        }
    }
    
    override var canPerformInteractiveDismissal: Bool {
        UIApplication.shared.statusBarOrientation.isPortrait
    }
    
    private var player: AVPlayer {
        return videoView.player
    }
    
    private var playerItemDuration: CMTime {
        player.currentItem?.duration ?? .invalid
    }
    
    private var pipModeLayoutInsets: UIEdgeInsets {
        let insets = parent?.view.safeAreaInsets ?? .zero
        return UIEdgeInsets(top: max(20, insets.top),
                            left: insets.left,
                            bottom: max(5, insets.bottom),
                            right: insets.right)
    }
    
    deinit {
        removeAllObservers()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if AVPictureInPictureController.isPictureInPictureSupported() {
            controlView.pipButton.addTarget(self, action: #selector(avPipAction), for: .touchUpInside)
            controlView.pipButton.isHidden = true
        } else {
            controlView.pipButton.addTarget(self, action: #selector(builtInPipAction), for: .touchUpInside)
            controlView.pipButton.isHidden = false
        }
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
        
        let panningController = ViewPanningController(view: view)
        panningController.isEnabled = isBuiltInPipActive
        self.panningController = panningController
        
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        videoView.addGestureRecognizer(tapRecognizer)
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView.frame = view.bounds
        videoView.clipsToBounds = true
        view.insertSubview(videoView, at: 0)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updatePipButtonVisibility(viewSize: size)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        videoRatio = 1
        isBuiltInPipActive = false
        videoView.isPipMode = false
        controlView.style.remove(.loading)
        controlView.playControlStyle = .play
        updateControlView(playControlsHidden: true, otherControlsHidden: true, animated: false)
        videoView.coverImageView.sd_cancelCurrentImageLoad()
        videoView.coverImageView.image = nil
        videoView.coverImageView.isHidden = false
        player.replaceCurrentItem(with: nil)
        hidePlayControlAfterPlaybackBegins = false
    }
    
    override func beginDownload() {
        guard let item = item, item.category == .video else {
            return
        }
        let job = AttachmentDownloadJob(transcriptId: item.transcriptId, messageId: item.messageId)
        ConcurrentJobQueue.shared.addJob(job: job)
        layout(mediaStatus: .PENDING)
    }
    
    override func cancelDownload() {
        guard let item = item else {
            return
        }
        let jobId = AttachmentDownloadJob.jobId(transcriptId: item.transcriptId, messageId: item.messageId)
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
        updateControlView(playControlsHidden: false, otherControlsHidden: true, animated: false)
        controlView.slider.value = controlView.slider.minimumValue
        controlView.playedTimeLabel.text = mediaDurationFormatter.string(from: 0)
        guard let item = item else {
            return
        }
        videoRatio = standardizedRatio(of: item.size)
        videoView.coverSize = item.size
        videoView.videoRatio = videoRatio
        videoView.setNeedsLayout()
        layoutFullsized()
        if item.category == .video {
            controlView.style.remove(.liveStream)
        } else if item.category == .live {
            controlView.style.insert(.liveStream)
        }
        if let url = item.url, item.category == .video {
            loadAssetIfPlayable(url: url, playAfterLoaded: false)
        }
        
        if AVPictureInPictureController.isPictureInPictureSupported(), let controller = avPipController ?? AVPictureInPictureController(playerLayer: videoView.playerView.layer) {
            controller.delegate = self
            if #available(iOS 14.2, *) {
                // Seems not working here. Don't know the reason
                controller.canStartPictureInPictureAutomaticallyFromInline = item.category == .live
            }
            if avPipPossibilityObservation == nil {
                avPipPossibilityObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] (_, _) in
                    guard let self = self else {
                        return
                    }
                    self.updatePipButtonVisibility(viewSize: self.view.bounds.size)
                }
            }
            avPipController = controller
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
        updateControlView(playControlsHidden: true, otherControlsHidden: true, animated: true)
    }
    
    override func didCancelInteractiveDismissal() {
        super.didCancelInteractiveDismissal()
        if player.timeControlStatus != .playing {
            updateControlView(playControlsHidden: false, otherControlsHidden: true, animated: true)
        }
    }
    
    func stopPipIfActive() {
        if isBuiltInPipActive {
            togglePipMode(completion: nil)
        } else if let controller = avPipController, controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        }
    }
    
    func togglePipMode(completion: (() -> Void)?) {
        executeInPortraitOrientation {
            self.isBuiltInPipActive.toggle()
            if self.isBuiltInPipActive {
                self.galleryViewController?.dismiss(pipController: self)
                if let container = UIApplication.homeContainerViewController {
                    container.pipController = self
                    container.overlaysCoordinator.register(overlay: self.view)
                }
            } else {
                self.galleryViewController?.show(itemViewController: self)
                if let container = UIApplication.homeContainerViewController {
                    container.pipController = nil
                    container.overlaysCoordinator.unregister(overlay: self.view)
                }
            }
            if self.player.timeControlStatus == .playing {
                self.updateControlView(playControlsHidden: true, otherControlsHidden: true, animated: false)
            }
            self.animate(animations: {
                self.videoView.isPipMode = self.isBuiltInPipActive
                if self.isBuiltInPipActive {
                    self.layoutPip()
                } else {
                    self.layoutFullsized()
                }
            }, completion: completion)
        }
    }
    
    func layoutPip() {
        controlView.pipButton.setImage(R.image.ic_maximize(), for: .normal)
        guard let parentView = parent?.view else {
            return
        }
        let size: CGSize
        if videoRatio > 1 {
            let width = parentView.bounds.width * (2 / 3)
            size = CGSize(width: width, height: width / videoRatio)
        } else {
            let height = parentView.bounds.height / 3
            let width = height * videoRatio
            if width <= parentView.bounds.width / 2 {
                size = CGSize(width: width, height: height)
            } else {
                let width = parentView.bounds.width / 2
                let height = width / videoRatio
                size = CGSize(width: width, height: height)
            }
        }
        view.frame.size = CGSize(width: size.width + builtInPipVideoInsets.horizontal,
                                 height: size.height + builtInPipVideoInsets.vertical)
        videoView.frame = view.bounds.inset(by: builtInPipVideoInsets)
        videoView.layer.cornerRadius = builtInPipCornerRadius
        
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowRadius = 4
        updateViewShadowOpacity(to: 0.14)
        
        panningController?.placeViewNextToLastOverlayOrTopRight()
    }
    
    func layoutFullsized() {
        controlView.pipButton.setImage(R.image.ic_minimize(), for: .normal)
        guard let parentView = parent?.view else {
            return
        }
        view.frame = parentView.bounds
        videoView.frame = view.bounds
        videoView.layer.cornerRadius = 0
        updateViewShadowOpacity(to: 0)
    }
    
    func stopAvPipAndHandoverDelegate(to delegate: AVPictureInPictureControllerDelegate) {
        if let controller = self.avPipController, controller.isPictureInPictureActive {
            controller.delegate = delegate
            controller.stopPictureInPicture()
        }
        restoreToFullsized()
    }
    
}

extension GalleryVideoItemViewController: AudioSessionClient {
    
    var priority: AudioSessionClientPriority {
        .playback
    }
    
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession) {
        pauseAction(audioSession)
        controlView.set(playControlsHidden: false, otherControlsHidden: false, animated: true)
    }
    
}

extension GalleryVideoItemViewController: AVPictureInPictureControllerDelegate {
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        galleryViewController?.dismiss(pipController: self)
        animate {
            self.view.alpha = 0
        }
        updateControlView(playControlsHidden: true, otherControlsHidden: true, animated: true)
        if let container = UIApplication.homeContainerViewController {
            container.pipController = self
        }
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        updateControlView(playControlsHidden: true, otherControlsHidden: true, animated: false)
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        updateControlView(playControlsHidden: false, otherControlsHidden: false, animated: true)
        if UIApplication.homeContainerViewController?.pipController == self {
            UIApplication.homeContainerViewController?.pipController = nil
        }
        if let parent = parent, parent is HomeContainerViewController {
            willMove(toParent: nil)
            view.removeFromSuperview()
            removeFromParent()
        }
        view.alpha = 1
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        controlView.pipButton.setImage(R.image.ic_minimize(), for: .normal)
        galleryViewController?.show(itemViewController: self)
        animate {
            self.view.alpha = 1
        } completion: {
            completionHandler(true)
        }
    }
    
}

extension GalleryVideoItemViewController {
    
    @objc func playAction(_ sender: Any) {
        if let controller = UIApplication.homeContainerViewController?.pipController, controller != self {
            if controller.item == self.item {
                controller.stopPipIfActive()
                return
            } else {
                controller.closeAction()
            }
        }
        guard let item = item else {
            return
        }
        playerDidFailedToPlay = false
        updateControlView(playControlsHidden: true, otherControlsHidden: true, animated: false)
        if item.category == .video || player.currentItem != nil {
            let mute: Bool
            do {
                try AudioSession.shared.activate(client: self) { (session) in
                    try session.setCategory(.playback, mode: .default, options: .defaultToSpeaker)
                }
                mute = false
            } catch AudioSession.Error.insufficientPriority {
                mute = true
            } catch {
                mute = false
            }
            player.isMuted = mute
            addTimeObservers()
            if playerDidReachEnd {
                playerDidReachEnd = false
                player.seek(to: .zero)
            }
            player.play()
        } else if let url = item.url {
            controlView.style.insert(.loading)
            loadAssetIfPlayable(url: url, playAfterLoaded: true)
        }
    }
    
    @objc func pauseAction(_ sender: Any) {
        removeTimeObservers()
        player.pause()
    }
    
    @objc func closeAction() {
        executeInPortraitOrientation {
            if self.isBuiltInPipActive {
                self.isBuiltInPipActive = false
                self.restoreToFullsized()
                self.player.replaceCurrentItem(with: nil)
            } else if !self.isAvPipActive {
                self.galleryViewController?.dismiss(transitionViewInitialOffsetY: 0)
                self.player.replaceCurrentItem(with: nil)
            }
        }
    }
    
    @objc private func builtInPipAction() {
        togglePipMode(completion: nil)
    }
    
    @objc private func avPipAction() {
        guard let controller = avPipController else {
            return
        }
        executeInPortraitOrientation {
            if controller.isPictureInPictureActive {
                controller.stopPictureInPicture()
            } else {
                controller.startPictureInPicture()
            }
        }
    }
    
    @objc private func reloadAction(_ sender: Any) {
        guard let url = item?.url else {
            return
        }
        playerDidReachEnd = false
        playerDidFailedToPlay = false
        loadAssetIfPlayable(url: url, playAfterLoaded: true)
    }
    
    @objc private func tapAction(_ recognizer: UITapGestureRecognizer) {
        if player.timeControlStatus == .playing {
            let isShowingPlayControl = controlView.playControlWrapperView.alpha > 0
            updateControlView(playControlsHidden: isShowingPlayControl,
                              otherControlsHidden: isShowingPlayControl,
                              animated: true)
        } else if controlView.style.contains(.loading) {
            let isShowingVisualControl = controlView.visualControlWrapperView.alpha > 0
            updateControlView(playControlsHidden: true,
                              otherControlsHidden: isShowingVisualControl,
                              animated: true)
        } else {
            let isShowingVisualControl = controlView.visualControlWrapperView.alpha > 0
            updateControlView(playControlsHidden: false,
                              otherControlsHidden: isShowingVisualControl,
                              animated: true)
        }
    }
    
    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        guard let item = item else {
            return
        }
        playerDidReachEnd = true
        if item.category == .video {
            controlView.playControlStyle = .play
        } else if item.category == .live {
            controlView.playControlStyle = .reload
        }
        updateControlView(playControlsHidden: false, otherControlsHidden: false, animated: true)
        removeTimeObservers()
        AudioSession.shared.deactivateAsynchronously(client: self, notifyOthersOnDeactivation: false)
    }
    
    @objc private func playerItemFailedToPlayToEndTime(_ notification: Notification) {
        playerDidFailedToPlay = true
        controlView.playControlStyle = .reload
        controlView.style.remove(.loading)
        updateControlView(playControlsHidden: false, otherControlsHidden: false, animated: true)
        removeTimeObservers()
        AudioSession.shared.deactivateAsynchronously(client: self, notifyOthersOnDeactivation: false)
    }
    
    @objc private func beginScrubbingAction(_ sender: Any) {
        rateBeforeSeeking = player.rate
        player.rate = 0
        removeTimeObservers()
    }
    
    @objc private func scrubAction(_ sender: Any) {
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
    
    @objc private func endScrubbingAction(_ sender: Any) {
        if sliderObserver == nil && timeLabelObserver == nil {
            addTimeObservers()
        }
        if let rate = rateBeforeSeeking {
            player.rate = rate
        }
        rateBeforeSeeking = nil
    }
    
}

extension GalleryVideoItemViewController {
    
    private func updateViewShadowOpacity(to opacity: Float) {
        view.layer.shadowOpacity = opacity
        let shadowOpacityAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.shadowOpacity))
        shadowOpacityAnimation.fromValue = view.layer.shadowOpacity
        shadowOpacityAnimation.toValue = opacity
        shadowOpacityAnimation.duration = animationDuration
        view.layer.add(shadowOpacityAnimation, forKey: shadowOpacityAnimation.keyPath)
    }
    
    private func executeInPortraitOrientation(_ work: @escaping () -> Void) {
        if UIApplication.shared.statusBarOrientation.isLandscape {
            let portrait = Int(UIInterfaceOrientation.portrait.rawValue)
            UIDevice.current.setValue(portrait, forKey: "orientation")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.33, execute: work)
        } else {
            work()
        }
    }
    
    private func loadAssetIfPlayable(url: URL, playAfterLoaded: Bool) {
        let asset = AVURLAsset(url: url)
        let playableKey = #keyPath(AVAsset.isPlayable)
        var error: NSError?
        
        func showReloadAndReport(error: Error?) {
            if let error = error {
                reporter.report(error: error)
            }
            controlView.style.remove(.loading)
            controlView.playControlStyle = .reload
            updateControlView(playControlsHidden: false, otherControlsHidden: false, animated: true)
        }
        
        if asset.statusOfValue(forKey: playableKey, error: &error) == .loaded {
            load(playableAsset: asset, playAfterLoaded: playAfterLoaded)
        } else if let error = error {
            showReloadAndReport(error: error)
        } else {
            asset.loadValuesAsynchronously(forKeys: [playableKey]) {
                guard asset.statusOfValue(forKey: playableKey, error: &error) == .loaded else {
                    DispatchQueue.main.async {
                        showReloadAndReport(error: error)
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
        itemPresentationSizeObserver = item.observe(\.presentationSize) { [weak self] (item, _) in
            self?.updateVideoViewSize(with: item)
        }
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(playerItemDidReachEnd(_:)),
                           name: .AVPlayerItemDidPlayToEndTime,
                           object: item)
        center.addObserver(self,
                           selector: #selector(playerItemFailedToPlayToEndTime(_:)),
                           name: .AVPlayerItemFailedToPlayToEndTime,
                           object: item)
        center.addObserver(self,
                           selector: #selector(pauseAction(_:)),
                           name: CallService.willStartCallNotification,
                           object: nil)
        
        timeControlObserver = player.observe(\.timeControlStatus, changeHandler: { [weak self] (player, _) in
            self?.updateControlView()
            self?.hideCoverIfPlaying()
        })
        
        player.replaceCurrentItem(with: item)
        if playAfterLoaded {
            let mute: Bool
            do {
                try AudioSession.shared.activate(client: self) { (session) in
                    try session.setCategory(.playback, mode: .default, options: .defaultToSpeaker)
                }
                mute = false
            } catch AudioSession.Error.insufficientPriority {
                mute = true
            } catch {
                mute = false
            }
            player.isMuted = mute
            player.play()
        }
    }
    
    private func updateControlView() {
        switch player.timeControlStatus {
        case .playing:
            controlView.playControlStyle = .pause
            controlView.style.remove(.loading)
            if hidePlayControlAfterPlaybackBegins {
                hidePlayControlAfterPlaybackBegins = false
                updateControlView(playControlsHidden: true, otherControlsHidden: true, animated: false)
            }
        case .paused:
            if item?.category == .video || (!playerDidReachEnd && !playerDidFailedToPlay) {
                controlView.playControlStyle = .play
            }
            updateControlView(playControlsHidden: false, otherControlsHidden: false, animated: true)
        case .waitingToPlayAtSpecifiedRate:
            if item?.category == .live {
                controlView.style.insert(.loading)
            }
        @unknown default:
            updateControlView(playControlsHidden: false, otherControlsHidden: false, animated: true)
        }
    }
    
    private func hideCoverIfPlaying() {
        guard player.timeControlStatus == .playing else {
            return
        }
        videoView.coverImageView.isHidden = true
    }
    
    private func updateVideoViewSize(with item: AVPlayerItem) {
        let videoRatio = standardizedRatio(of: item.presentationSize)
        self.videoRatio = videoRatio
        videoView.videoRatio = videoRatio
        videoView.setNeedsLayout()
        if isBuiltInPipActive {
            layoutPip()
        } else {
            layoutFullsized()
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
        itemPresentationSizeObserver?.invalidate()
        timeControlObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateControlView(playControlsHidden: Bool, otherControlsHidden: Bool, animated: Bool) {
        let hidePlayControls = playControlsHidden || !isPlayable
        let hideOtherControls = otherControlsHidden || !isPlayable || !(isFocused || UIApplication.homeContainerViewController?.pipController == self)
        controlView.set(playControlsHidden: hidePlayControls, otherControlsHidden: hideOtherControls, animated: animated)
    }
    
    private func standardizedRatio(of size: CGSize) -> CGFloat {
        guard !size.height.isZero else {
            return 1
        }
        let videoRatio = size.width / size.height
        guard !videoRatio.isNaN && !videoRatio.isZero else {
            return 1
        }
        return videoRatio
    }
    
    private func updatePipButtonVisibility(viewSize: CGSize) {
        let isDevicePortrait = viewSize.width < viewSize.height
        var isPipAvailable = isDevicePortrait
        if AVPictureInPictureController.isPictureInPictureSupported() {
            let isAvPipPossible = avPipController?.isPictureInPicturePossible ?? false
            isPipAvailable = isPipAvailable && isAvPipPossible
        }
        controlView.pipButton.isHidden = !isPipAvailable
    }
    
    private func restoreToFullsized() {
        layoutFullsized()
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
        if let container = UIApplication.homeContainerViewController, container.pipController == self {
            container.pipController = nil
            container.overlaysCoordinator.unregister(overlay: self.view)
        }
        view.alpha = 1
    }
    
}
