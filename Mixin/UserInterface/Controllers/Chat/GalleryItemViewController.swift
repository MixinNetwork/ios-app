import UIKit
import Photos
import SwiftMessages
import FLAnimatedImage

class GalleryItemViewController: UIViewController {
    
    @IBOutlet weak var videoView: GalleryVideoView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var mediaStatusView: UIStackView!
    @IBOutlet weak var operationButton: NetworkOperationButton!
    @IBOutlet weak var expiredHintLabel: UILabel!
    
    private static let qrCodeDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)

    let imageView = FLAnimatedImageView()
    
    private let animationDuration: TimeInterval = 0.3
    private let maximumZoomScale: CGFloat = 3

    private(set) var urlFromQRCode: URL?
    
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
                videoView.pause(hidePlayButton: false)
            }
        }
    }
    
    private var pageSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    private var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            var insets = view.safeAreaInsets
            if abs(insets.top - 20) < 0.1 {
                insets.top = max(0, insets.top - 20)
            }
            return insets
        } else {
            return .zero
        }
    }

    private var safeSize: CGSize {
        let safeAreaInsets = self.safeAreaInsets
        return CGSize(width: pageSize.width - safeAreaInsets.horizontal,
                      height: pageSize.height - safeAreaInsets.vertical)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.addSubview(imageView)
        scrollView.delegate = self
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        layoutImageView()
    }
    
    deinit {
        stopDownload()
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
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            performSavingToLibrary()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] (status) in
                switch status {
                case .authorized:
                    self?.performSavingToLibrary()
                case .denied, .notDetermined, .restricted:
                    DispatchQueue.main.async {
                        SwiftMessages.showToast(message: Localized.CAMERA_SAVE_PHOTO_FAILED, backgroundColor: .hintRed)
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                SwiftMessages.showToast(message: Localized.CAMERA_SAVE_PHOTO_FAILED, backgroundColor: .hintRed)
            }
        }
    }
    
    class func instance() -> GalleryItemViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "photo_preview_page") as! GalleryItemViewController
        return vc
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
    
    private func prepareForReuse() {
        scrollView.zoomScale = 1
        urlFromQRCode = nil
        imageView.sd_cancelCurrentImageLoad()
        scrollView.contentSize = pageSize
        videoView.pause(hidePlayButton: false)
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
            layout(mediaStatus: item.mediaStatus)
            if item.mediaStatus == .PENDING {
                beginDownload()
            }
            layoutImageView()
        }
    }
    
    private func loadImage(item: GalleryItem) {
        scrollView.isHidden = false
        videoView.isHidden = true
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
            var videoViewFrame = item.size.rect(fittingSize: safeSize, byContentMode: .scaleAspectFit)
            videoViewFrame.origin.y += safeAreaInsets.top
            videoView.frame = videoViewFrame
            videoView.loadVideo(url: url, playAfterLoaded: isFocused, thumbnail: item.thumbnail)
        } else {
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
            ConcurrentJobQueue.shared.addJob(job: AttachmentDownloadJob(messageId: photo.messageId))
        } else {
            FileJobQueue.shared.addJob(job: VideoDownloadJob(messageId: photo.messageId))
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
        let imageRatio = item.size.width / item.size.height
        let pageRatio = pageSize.width / pageSize.height
        if imageRatio <= pageRatio {
            let width = ceil(safeSize.height * imageRatio)
            imageView.frame = CGRect(x: safeAreaInsets.left + (safeSize.width - width) / 2,
                                     y: safeAreaInsets.top,
                                     width: width,
                                     height: safeSize.height)
        } else {
            let height = ceil(safeSize.width / imageRatio)
            imageView.frame = CGRect(x: safeAreaInsets.left,
                                     y: safeAreaInsets.top + (safeSize.height - height) / 2,
                                     width: safeSize.width,
                                     height: height)
        }
        scrollView.contentSize = imageView.frame.size
        let fittingScale: CGFloat
        if imageRatio > 1 {
            fittingScale = max(1, pageSize.height / imageView.frame.height)
        } else {
            fittingScale = max(1, pageSize.width / imageView.frame.width)
        }
        scrollView.maximumZoomScale = max(fittingScale, maximumZoomScale)
    }
    
}
