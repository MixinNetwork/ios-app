import UIKit
import Photos
import SwiftMessages
import FLAnimatedImage
import SnapKit

class GalleryItemViewController: UIViewController {
    
    @IBOutlet weak var videoView: GalleryVideoView!
    @IBOutlet weak var videoControlPanelView: UIView!
    @IBOutlet weak var playedTimeLabel: UILabel!
    @IBOutlet weak var slider: GalleryVideoSlider!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var mediaStatusView: UIStackView!
    @IBOutlet weak var operationButton: NetworkOperationButton!
    @IBOutlet weak var expiredHintLabel: UILabel!
    @IBOutlet var timeLabels: [UILabel]!
    @IBOutlet var videoControlViews: [UIView]!
    
    @IBOutlet var tapRecognizer: UITapGestureRecognizer!
    
    private static let qrCodeDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)
    
    let imageView = FLAnimatedImageView()
    
    private let animationDuration: TimeInterval = 0.3
    private let maximumZoomScale: CGFloat = 3
    private let sliderObserverInterval = CMTime(seconds: 0.1, preferredTimescale: nanosecondsPerSecond)
    private let timeLabelObserverInterval = CMTime(seconds: 1, preferredTimescale: nanosecondsPerSecond)
    private let rateKey = "rate"
    
    private(set) var urlFromQRCode: URL?
    
    private var videoControlPanelEdgesConstraint: Constraint!
    private var sliderObserver: Any?
    private var timeLabelObserver: Any?
    private var isSeeking = false
    private var rateBeforeScrubbing: Float = 0
    private var seekToZeroBeforePlaying = false
    private var isObservingRate = false
    
    struct ObserveContext {
        static var rateObservingContext = 0
    }
    
    var item: GalleryItem? {
        didSet {
            guard item != oldValue else {
                return
            }
            loadItem(item)
        }
    }
    
    var isFocused = false {
        didSet {
            guard isFocused != oldValue else {
                return
            }
            if !isFocused, item?.category == .video {
                videoView.player.rate = 0
                videoView.player.seek(to: kCMTimeZero)
                setPlayButtonHidden(false, otherControlsHidden: true, animated: false)
            }
        }
    }
    
    var isPlayingVideo: Bool {
        return rateBeforeScrubbing > 0 || videoView.player.rate > 0
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.addSubview(imageView)
        scrollView.delegate = self
        tapRecognizer.delegate = self
        videoControlPanelView.translatesAutoresizingMaskIntoConstraints = false
        videoControlPanelView.snp.makeConstraints { (make) in
            videoControlPanelEdgesConstraint = make.edges.equalToSuperview().inset(fullScreenSafeAreaInsets).constraint
        }
        mediaStatusView.translatesAutoresizingMaskIntoConstraints = false
        mediaStatusView.snp.makeConstraints { (make) in
            make.center.equalTo(videoControlPanelView)
        }
        for label in timeLabels {
            label.layer.shadowRadius = 4
            label.layer.shadowOpacity = 0.6
            label.layer.shadowOffset = .zero
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: .UIApplicationWillResignActive, object: nil)
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        layoutImageView()
        videoControlPanelEdgesConstraint.update(inset: fullScreenSafeAreaInsets)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &ObserveContext.rateObservingContext {
            let image = isPlayingVideo ? #imageLiteral(resourceName: "ic_pause") : #imageLiteral(resourceName: "ic_play")
            playButton.setImage(image, for: .normal)
            if isPlayingVideo && !isSeeking {
                setPlayButtonHidden(true, otherControlsHidden: true, animated: true)
            }
            UIApplication.shared.isIdleTimerDisabled = isPlayingVideo
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if isObservingRate {
            videoView.player.removeObserver(self, forKeyPath: rateKey)
        }
        if let observer = timeLabelObserver {
            videoView.player.removeTimeObserver(observer)
        }
        timeLabelObserver = nil
        if let observer = sliderObserver {
            videoView.player.removeTimeObserver(observer)
        }
        sliderObserver = nil
        stopDownload()
    }
    
    @objc func applicationWillResignActive(_ notification: Notification) {
        videoView.player.rate = 0
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        galleryViewController?.dismiss()
    }
    
    @IBAction func playAction(_ sender: Any) {
        if seekToZeroBeforePlaying {
            videoView.player.seek(to: kCMTimeZero)
            seekToZeroBeforePlaying = false
        }
        videoView.player.rate = round(abs(1 - videoView.player.rate))
    }
    
    @IBAction func photoDownloadAction(_ sender: Any) {
        switch operationButton.style {
        case .busy(_):
            stopDownload()
        case .download:
            beginDownload()
        default:
            break
        }
    }
    
    @IBAction func beginScrubbingAction(_ sender: Any) {
        rateBeforeScrubbing = videoView.player.rate
        videoView.player.rate = 0
        if let observer = sliderObserver {
            videoView.player.removeTimeObserver(observer)
            sliderObserver = nil
        }
    }
    
    @IBAction func scrubAction(_ sender: Any) {
        guard !isSeeking, let playerItemDuration = playerItemDuration else {
            return
        }
        isSeeking = true
        let duration = CMTimeGetSeconds(playerItemDuration)
        if duration.isFinite {
            let min = slider.minimumValue
            let max = slider.maximumValue
            let value = slider.value
            let seconds = duration * Double(value - min) / Double(max - min)
            let time = CMTime(seconds: seconds, preferredTimescale: nanosecondsPerSecond)
            videoView.player.seek(to: time, completionHandler: { (_) in
                DispatchQueue.main.async {
                    self.isSeeking = false
                }
            })
        }
    }
    
    @IBAction func endScrubbingAction(_ sender: Any) {
        if sliderObserver == nil, let playerItemDuration = playerItemDuration {
            let seconds = CMTimeGetSeconds(playerItemDuration)
            let tolerance = 0.5 * seconds / Double(slider.bounds.width)
            let time = CMTime(seconds: tolerance, preferredTimescale: nanosecondsPerSecond)
            sliderObserver = videoView.player.addPeriodicTimeObserver(forInterval: time, queue: .main, using: { [weak self] (_) in
                self?.syncScrubberPosition()
            })
        }
        videoView.player.rate = rateBeforeScrubbing
        rateBeforeScrubbing = 0
    }
    
    @IBAction func tapAction(_ sender: Any) {
        guard item?.category == .video else {
            return
        }
        if item?.url != nil, videoView.player.status == .readyToPlay {
            let isShowingControls = videoControlViews[0].alpha > 0
            setPlayButtonHidden(isShowingControls, otherControlsHidden: isShowingControls, animated: true)
        }
    }
    
    @objc func playerItemDidReachEnd(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem, item == videoView.player.currentItem else {
            return
        }
        seekToZeroBeforePlaying = true
        setPlayButtonHidden(false, otherControlsHidden: true, animated: true)
    }
    
    func zoom(location: CGPoint) {
        if abs(scrollView.zoomScale - scrollView.maximumZoomScale) > 0.1 {
            let size = ceil(CGSize(width: scrollView.frame.width / scrollView.maximumZoomScale,
                                   height: scrollView.frame.height / scrollView.maximumZoomScale))
            let origin = CGPoint(x: max(imageView.frame.minX, min(imageView.frame.maxX, location.x - (size.width / 2))),
                                 y: max(imageView.frame.minY, min(imageView.frame.maxY, location.y - (size.height / 2))))
            let zoomingRect = scrollView.convert(CGRect(origin: origin, size: size), to: imageView)
            scrollView.zoom(to: zoomingRect, animated: true)
        } else {
            UIView.animate(withDuration: animationDuration) {
                self.scrollView.zoomScale = self.scrollView.minimumZoomScale
            }
        }
    }
    
    func saveToLibrary() {
        PHPhotoLibrary.checkAuthorization { [weak self](authorized) in
            guard authorized else {
                return
            }
            self?.performSavingToLibrary()
        }
    }
    
    class func instance() -> GalleryItemViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "photo_preview_page") as! GalleryItemViewController
        return vc
    }
    
}

extension GalleryItemViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == tapRecognizer else {
            return true
        }
        return !slider.bounds.contains(gestureRecognizer.location(in: slider))
    }
    
}

extension GalleryItemViewController: UIScrollViewDelegate {
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offset = CGPoint(x: max(0, (scrollView.frame.width - scrollView.contentSize.width) / 2),
                             y: max(0, (scrollView.frame.height - scrollView.contentSize.height) / 2))
        imageView.center = CGPoint(x: scrollView.contentSize.width / 2 + offset.x,
                                   y: scrollView.contentSize.height / 2 + offset.y)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
}

extension GalleryItemViewController {
    
    private var galleryViewController: GalleryViewController? {
        return parent as? GalleryViewController
    }

    private var pageSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    private var contentSize: CGSize {
        let insets = self.fullScreenSafeAreaInsets
        return CGSize(width: pageSize.width - insets.horizontal,
                      height: pageSize.height - insets.vertical)
    }
    
    private var playerItemDuration: CMTime? {
        guard let item = videoView.player.currentItem else {
            return nil
        }
        if item.status == .readyToPlay {
            let duration = item.duration
            if duration.isValid {
                return duration
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    private func prepareForReuse() {
        scrollView.zoomScale = 1
        urlFromQRCode = nil
        imageView.sd_cancelCurrentImageLoad()
        scrollView.contentSize = pageSize
        videoView.player.rate = 0
        videoView.player.seek(to: kCMTimeZero)
        if let item = videoView.player.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
        }
        if isObservingRate {
            videoView.player.removeObserver(self, forKeyPath: rateKey)
            isObservingRate = false
        }
    }
    
    private func loadItem(_ item: GalleryItem?) {
        prepareForReuse()
        imageView.image = item?.thumbnail
        if let item = item {
            switch item.category {
            case .image:
                loadImage(item: item)
            case .video:
                loadVideo(item: item)
            }
            layoutImageView()
            layout(mediaStatus: item.mediaStatus)
            if item.mediaStatus == .PENDING {
                beginDownload()
            }
        }
    }
    
    private func loadImage(item: GalleryItem) {
        scrollView.isHidden = false
        videoView.isHidden = true
        videoControlPanelView.isHidden = true
        tapRecognizer.isEnabled = false
        guard let url = item.url else {
            return
        }
        imageView.sd_setImage(with: url, placeholderImage: nil, options: [], completed: { [weak self] (image, _, _, _) in
            guard let image = image else {
                return
            }
            DispatchQueue.global().async {
                guard self != nil, self?.item?.messageId == item.messageId, let ciImage = CIImage(image: image), let features = GalleryItemViewController.qrCodeDetector?.features(in: ciImage) else {
                    return
                }
                for case let feature as CIQRCodeFeature in features {
                    guard let messageString = feature.messageString, let url = URL(string: messageString) else {
                        continue
                    }
                    DispatchQueue.main.async {
                        if self?.item?.messageId == item.messageId {
                            self?.urlFromQRCode = url
                        }
                    }
                    break
                }
            }
        })
    }
    
    private func loadVideo(item: GalleryItem) {
        if let url = item.url {
            scrollView.isHidden = true
            videoView.isHidden = false
            videoControlPanelView.isHidden = false
            tapRecognizer.isEnabled = true
            videoView.frame = UIEdgeInsetsInsetRect(view.bounds, fullScreenSafeAreaInsets)
            let playAfterLoaded = isFocused
            playButton.setImage(playAfterLoaded ? #imageLiteral(resourceName: "ic_pause") : #imageLiteral(resourceName: "ic_play"), for: .normal)
            setPlayButtonHidden(playAfterLoaded, otherControlsHidden: true, animated: false)
            if let observer = sliderObserver {
                videoView.player.removeTimeObserver(observer)
            }
            sliderObserver = videoView.player.addPeriodicTimeObserver(forInterval: sliderObserverInterval, queue: .main, using: { [weak self] (_) in
                self?.syncScrubberPosition()
            })
            if let observer = timeLabelObserver {
                videoView.player.removeTimeObserver(observer)
            }
            timeLabelObserver = videoView.player.addPeriodicTimeObserver(forInterval: timeLabelObserverInterval, queue: .main, using: { [weak self] (_) in
                guard let weakSelf = self else {
                    return
                }
                if let item = weakSelf.videoView.player.currentItem, item.status == .readyToPlay {
                    let duration = CMTimeGetSeconds(item.duration)
                    if duration.isFinite {
                        let time = CMTimeGetSeconds(weakSelf.videoView.player.currentTime())
                        weakSelf.playedTimeLabel.text = mediaDurationFormatter.string(from: time)
                        weakSelf.remainingTimeLabel.text = mediaDurationFormatter.string(from: duration - time)
                    }
                }
            })
            videoView.player.addObserver(self, forKeyPath: rateKey, options: [.initial, .new], context: &ObserveContext.rateObservingContext)
            isObservingRate = true
            videoView.loadVideo(url: url, playAfterLoaded: playAfterLoaded, thumbnail: item.thumbnail)
            if let item = videoView.player.currentItem {
                let duration = CMTimeGetSeconds(item.asset.duration)
                if duration.isFinite {
                    remainingTimeLabel.text = mediaDurationFormatter.string(from: duration)
                }
            }
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: videoView.player.currentItem)
        } else {
            setPlayButtonHidden(true, otherControlsHidden: true, animated: false)
            scrollView.isHidden = false
            videoView.isHidden = true
            imageView.image = item.thumbnail
        }
    }
    
    private func performSavingToLibrary() {
        guard let url = item?.url else {
            return
        }
        if item?.category == .image {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            }, completionHandler: { (success, error) in
                DispatchQueue.main.async {
                    if success {
                        SwiftMessages.showToast(message: Localized.CAMERA_SAVE_PHOTO_SUCCESS, backgroundColor: .hintGreen)
                    } else {
                        SwiftMessages.showToast(message: Localized.CAMERA_SAVE_PHOTO_FAILED, backgroundColor: .hintRed)
                    }
                }
            })
        } else if item?.category == .video {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }, completionHandler: { (success, error) in
                if success {
                    SwiftMessages.showToast(message: Localized.CAMERA_SAVE_VIDEO_SUCCESS, backgroundColor: .hintGreen)
                } else {
                    SwiftMessages.showToast(message: Localized.CAMERA_SAVE_VIDEO_FAILED, backgroundColor: .hintRed)
                }
            })
        }
    }
    
    private func beginDownload() {
        guard let photo  = item else {
            return
        }
        layout(mediaStatus: .PENDING)
        imageView.image = photo.thumbnail
        if item?.category == .image {
            ConcurrentJobQueue.shared.addJob(job: AttachmentDownloadJob(messageId: photo.messageId, mediaMimeType: photo.mediaMimeType))
        } else {
            FileJobQueue.shared.addJob(job: VideoDownloadJob(messageId: photo.messageId, mediaMimeType: photo.mediaMimeType))
        }
    }
    
    private func stopDownload() {
        guard let messageId = item?.messageId else {
            return
        }
        layout(mediaStatus: .CANCELED)
        if item?.category == .image {
            let jobId = AttachmentDownloadJob.jobId(messageId: messageId)
            ConcurrentJobQueue.shared.cancelJob(jobId: jobId)
        } else {
            let jobId = VideoDownloadJob.jobId(messageId: messageId)
            FileJobQueue.shared.cancelJob(jobId: jobId)
        }
    }
    
    private func layout(mediaStatus: MediaStatus?) {
        if let mediaStatus = mediaStatus {
            switch mediaStatus {
            case .PENDING:
                mediaStatusView.isHidden = false
                expiredHintLabel.isHidden = true
                operationButton.style = .busy(progress: 0)
            case .DONE:
                mediaStatusView.isHidden = true
                expiredHintLabel.isHidden = true
                operationButton.style = .finished(showPlayIcon: false)
            case .CANCELED:
                mediaStatusView.isHidden = false
                expiredHintLabel.isHidden = true
                operationButton.style = .download
            case .EXPIRED:
                mediaStatusView.isHidden = false
                expiredHintLabel.isHidden = false
                operationButton.style = .expired
            }
        } else {
            mediaStatusView.isHidden = true
            expiredHintLabel.isHidden = true
            operationButton.style = .finished(showPlayIcon: false)
        }
    }
    
    private func layoutImageView() {
        guard let item = item, (scrollView.zoomScale - 1) < 0.1 else {
            return
        }
        var imageRect = item.size.rect(fittingSize: contentSize, byContentMode: .scaleAspectFit)
        imageRect.origin = CGPoint(x: imageRect.origin.x + fullScreenSafeAreaInsets.left,
                                   y: imageRect.origin.y + fullScreenSafeAreaInsets.top)
        imageView.frame = imageRect
        scrollView.contentSize = imageView.frame.size
        let fittingScale: CGFloat
        if item.size.width / item.size.height > 1 {
            fittingScale = max(1, pageSize.height / imageView.frame.height)
        } else {
            fittingScale = max(1, pageSize.width / imageView.frame.width)
        }
        scrollView.maximumZoomScale = max(fittingScale, maximumZoomScale)
    }
    
    private func syncScrubberPosition() {
        guard let itemDuration = playerItemDuration else {
            return
        }
        let duration = CMTimeGetSeconds(itemDuration)
        if duration.isFinite {
            let max = slider.maximumValue
            let min = slider.minimumValue
            let time = CMTimeGetSeconds(videoView.player.currentTime())
            slider.value = Float(Double(max - min) * time / duration + Double(min))
        }
    }
    
    private func setPlayButtonHidden(_ playButtonHidden: Bool, otherControlsHidden: Bool, animated: Bool) {
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(animationDuration)
        }
        playButton.alpha = playButtonHidden ? 0 : 1
        videoControlViews.forEach {
            $0.alpha = otherControlsHidden ? 0 : 1
        }
        if animated {
            UIView.commitAnimations()
        }
    }
    
}
