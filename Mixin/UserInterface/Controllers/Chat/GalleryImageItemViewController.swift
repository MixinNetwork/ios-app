import UIKit
import SDWebImage
import Photos
import MixinServices

final class GalleryImageItemViewController: GalleryItemViewController {
    
    let scrollView = UIScrollView()
    let imageView = SDAnimatedImageView()
    
    private(set) var detectedUrl: URL?
    
    private let maximumZoomScale: CGFloat = 3
    
    private lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
    private lazy var zoomRecognizer = UITapGestureRecognizer(target: self, action: #selector(zoomAction(_:)))
    
    private var displayAwakeningToken: DisplayAwakener.Token?
    private var animatedImageRepeatObserver: NSKeyValueObservation?
    
    var relativeOffset: CGFloat {
        let maxRelativeOffset = (scrollView.contentSize.height / scrollView.zoomScale - scrollView.frame.height) / (scrollView.contentSize.height / scrollView.zoomScale)
        let offset = scrollView.contentOffset.y / scrollView.contentSize.height
        return -min(maxRelativeOffset, offset)
    }
    
    override var isDownloadingAttachment: Bool {
        guard let item = item else {
            return false
        }
        let jobId = AttachmentDownloadJob.jobId(transcriptId: item.transcriptId, messageId: item.messageId)
        return ConcurrentJobQueue.shared.isExistJob(jodId: jobId)
    }
    
    override var shouldDownloadAutomatically: Bool {
        switch AppGroupUserDefaults.User.autoDownloadPhotos {
        case .wifiAndCellular:
            return true
        case .wifi:
            return ReachabilityManger.shared.isReachableOnEthernetOrWiFi
        case .never:
            return false
        }
    }
    
    override var image: UIImage? {
        return imageView.image
    }
    
    override var isReusable: Bool {
        return parent == nil
    }
    
    override var supportedActions: Action {
        [.forward, .saveToLibrary]
    }
    
    override var canPerformInteractiveDismissal: Bool {
        return abs(scrollView.contentOffset.y + scrollView.adjustedContentInset.top) < 1
    }
    
    override var isFocused: Bool {
        didSet {
            if isFocused, let image = imageView.image {
                keepDisplayWakingUpIfNeeded(image: image)
            } else if !isFocused {
                stopAwakeningDisplay()
            }
        }
    }
    
    private var pageSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        if let interactiveDismissalGestureRecognizer = galleryViewController?.panRecognizer {
            scrollView.panGestureRecognizer.require(toFail: interactiveDismissalGestureRecognizer)
        }
        scrollView.addSubview(imageView)
        scrollView.delegate = self
        view.insertSubview(scrollView, at: 0)
        scrollView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        zoomRecognizer.numberOfTapsRequired = 2
        tapRecognizer.require(toFail: zoomRecognizer)
        view.addGestureRecognizer(tapRecognizer)
        view.addGestureRecognizer(zoomRecognizer)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        scrollView.zoomScale = 1
        scrollView.contentSize = pageSize
        detectedUrl = nil
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
    }
    
    override func beginDownload() {
        guard let item = item else {
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
            imageView.image = image
        case .url(let url):
            imageView.sd_setImage(with: url)
        case .none:
            break
        }
    }
    
    override func load(item: GalleryItem?) {
        super.load(item: item)
        guard let item = item else {
            return
        }
        
        if let url = item.url {
            imageView.sd_setImage(with: url, placeholderImage: imageView.image, context: localImageContext, progress: nil) { [weak self] (image, error, cacheType, url) in
                guard let self = self, self.item == item, let image = image else {
                    return
                }
                self.detectQRCode(for: item, image: image)
                self.keepDisplayWakingUpIfNeeded(image: image)
            }
        }
        
        let imageRect: CGRect
        if item.shouldLayoutAsArticle {
            let height = pageSize.width * item.size.height / item.size.width
            imageRect = CGRect(x: 0, y: 0, width: pageSize.width, height: height)
        } else {
            imageRect = item.size.rect(fittingSize: pageSize)
        }
        imageView.frame = imageRect
        scrollView.contentSize = imageView.frame.size
        let fittingScale: CGFloat
        if item.size.width / item.size.height > 1 {
            fittingScale = max(1, pageSize.height / imageView.frame.height)
        } else {
            fittingScale = max(1, pageSize.width / imageView.frame.width)
        }
        scrollView.maximumZoomScale = max(fittingScale, maximumZoomScale)
        scrollView.contentOffset = .zero
        updateVerticalScrollIndicatorVisibility(with: item)
    }
    
    override func saveToLibrary() {
        guard let url = item?.url else {
            showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_save_photo())
            return
        }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
        }, completionHandler: { (success, error) in
            DispatchQueue.main.async {
                if success {
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.photo_saved())
                } else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_save_photo())
                }
            }
        })
    }
    
    override func layout(mediaStatus: MediaStatus) {
        super.layout(mediaStatus: mediaStatus)
        scrollView.isScrollEnabled = mediaStatus == .DONE || mediaStatus == .READ
    }
    
    @objc func tapAction(_ recognizer: UITapGestureRecognizer) {
        galleryViewController?.dismiss(transitionViewInitialOffsetY: 0)
    }
    
    @objc func zoomAction(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: scrollView)
        if abs(scrollView.zoomScale - scrollView.maximumZoomScale) > 0.1 {
            let size = ceil(CGSize(width: scrollView.frame.width / scrollView.maximumZoomScale,
                                   height: scrollView.frame.height / scrollView.maximumZoomScale))
            let origin = CGPoint(x: max(imageView.frame.minX, min(imageView.frame.maxX, location.x - (size.width / 2))),
                                 y: max(imageView.frame.minY, min(imageView.frame.maxY, location.y - (size.height / 2))))
            let zoomingRect = scrollView.convert(CGRect(origin: origin, size: size), to: imageView)
            scrollView.zoom(to: zoomingRect, animated: true)
        } else {
            UIView.animate(withDuration: 0.3) {
                self.scrollView.zoomScale = self.scrollView.minimumZoomScale
            }
        }
    }
    
}

extension GalleryImageItemViewController: UIScrollViewDelegate {
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let visibleSize = scrollView.frame.size
        if scrollView.contentSize.width < visibleSize.width {
            imageView.center.x = visibleSize.width / 2
        } else {
            imageView.center.x = scrollView.contentSize.width / 2
        }
        if scrollView.contentSize.height < visibleSize.height {
            imageView.center.y = visibleSize.height / 2
        } else {
            imageView.center.y = scrollView.contentSize.height / 2
        }
        updateVerticalScrollIndicatorVisibility(with: item)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
}

extension GalleryImageItemViewController {
    
    private func detectQRCode(for item: GalleryItem, image: UIImage) {
        guard let detector = qrCodeDetector, let cgImage = image.cgImage else {
            return
        }
        DispatchQueue.global().async { [weak self] in
            let ciImage = CIImage(cgImage: cgImage)
            let features = detector.features(in: ciImage)
            for case let feature as CIQRCodeFeature in features {
                guard let string = feature.messageString, let url = URL(string: string) else {
                    continue
                }
                DispatchQueue.main.async {
                    guard let self = self, self.item == item else {
                        return
                    }
                    self.detectedUrl = url
                }
                return
            }
        }
    }
    
    private func keepDisplayWakingUpIfNeeded(image: UIImage) {
        guard isFocused else {
            return
        }
        guard let image = image as? SDAnimatedImage, image.sd_imageFrameCount > 1 else {
            return
        }
        if displayAwakeningToken == nil {
            displayAwakeningToken = DisplayAwakener.shared.retain()
        }
        if animatedImageRepeatObserver == nil {
            animatedImageRepeatObserver = imageView.observe(\.currentLoopCount) { (imageView, _) in
                if imageView.currentLoopCount == 1 {
                    self.stopAwakeningDisplay()
                }
            }
        }
    }
    
    private func stopAwakeningDisplay() {
        animatedImageRepeatObserver = nil
        if let token = displayAwakeningToken {
            DisplayAwakener.shared.release(token: token)
            displayAwakeningToken = nil
        }
    }
    
    private func updateVerticalScrollIndicatorVisibility(with item: GalleryItem?) {
        if scrollView.zoomScale == 1, let item = item {
            scrollView.showsVerticalScrollIndicator = item.shouldLayoutAsArticle
        } else {
            scrollView.showsVerticalScrollIndicator = false
        }
    }
    
}
