import UIKit
import Photos
import SDWebImage
import CoreServices
import MixinServices

final class MediaPreviewViewController: UIViewController {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var imageView: SDAnimatedImageView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    
    @IBOutlet weak var stackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var minimalImageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var normalImageViewWidthConstraint: NSLayoutConstraint!
    
    weak var conversationInputViewController: ConversationInputViewController?
    
    private var lastRequestId: PHImageRequestID?
    private var asset: Asset?
    private var playerView: PlayerView?
    private var playerObservation: NSKeyValueObservation?
    private var seekToZeroBeforePlay = false
    
    private var movieTypeIdentifier: String {
        if #available(iOS 14.0, *) {
            return UTType.movie.identifier
        } else {
            return kUTTypeMovie as String
        }
    }
    
    private var gifTypeIdentifier: String {
        if #available(iOS 14.0, *) {
            return UTType.gif.identifier
        } else {
            return kUTTypeGIF as String
        }
    }
    
    private lazy var videoThumbnailMaskLayer: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = UIColor.white.cgColor
        return layer
    }()
    private lazy var imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        return options
    }()
    private lazy var offlineVideoRequestOptions: PHVideoRequestOptions = {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = false
        options.version = .current
        options.deliveryMode = .mediumQualityFormat
        options.progressHandler = nil
        return options
    }()
    private lazy var onlineVideoRequestOptions: PHVideoRequestOptions = {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        options.deliveryMode = .mediumQualityFormat
        options.progressHandler = nil
        return options
    }()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.autoPlayAnimatedImage = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let id = lastRequestId {
            PHImageManager.default().cancelImageRequest(id)
        }
        playerView?.layer.player?.rate = 0
        playerObservation?.invalidate()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        stackViewBottomConstraint.constant = max(view.safeAreaInsets.bottom, stackViewBottomConstraint.constant)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let height = stackView.frame.height + stackViewBottomConstraint.constant
        preferredContentSize = CGSize(width: view.frame.width, height: height)
    }
    
    @IBAction func playAction(_ sender: Any) {
        guard let asset = self.asset else {
            return
        }
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
        switch asset {
        case .phAsset(let asset):
            requestAndPlay(asset: asset, mute: mute)
        case .video(let url):
            playVideo(at: url, mute: mute)
        default:
            break
        }
    }
    
    @IBAction func pauseAction(_ sender: Any) {
        playerView?.layer.player?.pause()
    }
    
    @IBAction func sendAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        switch asset {
        case let .phAsset(asset):
            conversationInputViewController?.send(asset: asset)
        case let .image(image):
            conversationInputViewController?.send(image: image)
        case let .video(url):
            conversationInputViewController?.moveAndSendVideo(at: url)
        case let .gif(url, image):
            conversationInputViewController?.moveAndSendGifImage(at: url, image: image)
        case .none:
            break
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        AudioSession.shared.deactivateAsynchronously(client: self, notifyOthersOnDeactivation: true)
        dismiss(animated: true, completion: nil)
        switch asset {
        case let .video(url), let .gif(url, _):
            try? FileManager.default.removeItem(at: url)
        default:
            break
        }
    }
    
    func load(asset: PHAsset) {
        self.asset = .phAsset(asset)
        loadViewIfNeeded()
        activityIndicator.startAnimating()
        let targetSize = imageView.bounds.size * UIScreen.main.scale
        lastRequestId = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: imageRequestOptions) { [weak self] (image, info) in
            guard let weakSelf = self, let image = image else {
                return
            }
            if asset.mediaType == .image {
                let assetPixelSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                weakSelf.updateImageViewSizeForImages(with: assetPixelSize)
            } else {
                weakSelf.updateImageViewSizeForVideos()
            }
            weakSelf.imageView.image = image
            weakSelf.lastRequestId = nil
            weakSelf.activityIndicator.stopAnimating()
            weakSelf.playButton.isHidden = asset.mediaType != .video
            weakSelf.view.layoutIfNeeded()
            if asset.isGif {
                if let id = weakSelf.lastRequestId {
                    PHImageManager.default().cancelImageRequest(id)
                }
                weakSelf.loadAnimatedImage(asset: asset)
            }
        }
    }
    
    func canLoad(itemProvider: NSItemProvider) -> Bool {
        itemProvider.hasItemConformingToTypeIdentifier(gifTypeIdentifier)
            || itemProvider.hasItemConformingToTypeIdentifier(movieTypeIdentifier)
            || itemProvider.canLoadObject(ofClass: UIImage.self)
    }
    
    func load(itemProvider: NSItemProvider) {
        loadViewIfNeeded()
        activityIndicator.startAnimating()
        if itemProvider.hasItemConformingToTypeIdentifier(gifTypeIdentifier) {
            copyFile(from: itemProvider, identifier: gifTypeIdentifier) { _ in
                FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ExtensionName.gif.withDot)
            } completion: { [weak self] url in
                guard let image = SDAnimatedImage(contentsOfFile: url.path) else {
                    return
                }
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    self.asset = .gif(url, image)
                    let assetPixelSize = image.size * image.scale
                    self.updateImageViewSizeForImages(with: assetPixelSize)
                    self.imageView.image = image
                    self.activityIndicator.stopAnimating()
                    self.playButton.isHidden = true
                    self.view.layoutIfNeeded()
                }
            }
        } else if itemProvider.hasItemConformingToTypeIdentifier(movieTypeIdentifier) {
            // A video file in temp directory or with no extension name is not playable
            guard let document = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            copyFile(from: itemProvider, identifier: movieTypeIdentifier) { source in
                document.appendingPathComponent(UUID().uuidString).appendingPathExtension(source.pathExtension)
            } completion: { [weak self] url in
                let thumbnail = UIImage(withFirstFrameOfVideoAtURL: url)
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    self.asset = .video(url)
                    self.updateImageViewSizeForVideos()
                    self.imageView.image = thumbnail
                    self.activityIndicator.stopAnimating()
                    self.playButton.isHidden = false
                    self.view.layoutIfNeeded()
                }
            }
        } else if itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] (rawImage, error) in
                guard
                    let rawImage = rawImage as? UIImage,
                    let image = ImageUploadSanitizer.sanitizedImage(from: rawImage).image
                else {
                    if let error = error {
                        reporter.report(error: error)
                    }
                    DispatchQueue.main.async {
                        guard let self = self else {
                            return
                        }
                        showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_share_content())
                        self.dismiss(animated: true, completion: nil)
                    }
                    return
                }
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    self.asset = .image(image)
                    let assetPixelSize = image.size * image.scale
                    self.updateImageViewSizeForImages(with: assetPixelSize)
                    self.imageView.image = image
                    self.activityIndicator.stopAnimating()
                    self.playButton.isHidden = true
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
    
    @objc private func playerItemDidPlayToEndTime() {
        AudioSession.shared.deactivateAsynchronously(client: self, notifyOthersOnDeactivation: true)
        DispatchQueue.main.async {
            self.seekToZeroBeforePlay = true
        }
    }
    
}

extension MediaPreviewViewController: AudioSessionClient {
    
    var priority: AudioSessionClientPriority {
        .playback
    }
    
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession) {
        pauseAction(audioSession)
    }
    
}

extension MediaPreviewViewController {
    
    private enum Asset {
        case phAsset(PHAsset)
        case gif(URL, UIImage)
        case video(URL)
        case image(UIImage)
    }
    
    enum Error: Swift.Error {
        case loadFileRepresentation(Swift.Error?)
        case copyItem(Swift.Error)
    }
    
    // The completion is only called on success
    private func copyFile(
        from provider: NSItemProvider,
        identifier: String,
        to makeDestinationURL: @escaping (URL) -> URL,
        completion: @escaping (URL) -> Void
    ) {
        provider.loadFileRepresentation(forTypeIdentifier: identifier) { (source, error) in
            if let source = source {
                do {
                    let destination = makeDestinationURL(source)
                    try FileManager.default.copyItem(at: source, to: destination)
                    completion(destination)
                } catch {
                    reporter.report(error: Error.copyItem(error))
                }
            } else {
                reporter.report(error: Error.loadFileRepresentation(error))
            }
        }
    }
    
    private func updateImageViewSizeForImages(with pixelSize: CGSize) {
        let imageViewPixelSize = imageView.bounds.size * UIScreen.main.scale
        let useMinimalImageViewSize = pixelSize.width < imageViewPixelSize.width / 3
            && pixelSize.height < imageViewPixelSize.height / 3
        if useMinimalImageViewSize {
            minimalImageViewWidthConstraint.priority = .almostRequired
            normalImageViewWidthConstraint.priority = .almostInexist
        } else {
            minimalImageViewWidthConstraint.priority = .almostInexist
            normalImageViewWidthConstraint.priority = .almostRequired
        }
    }
    
    private func updateImageViewSizeForVideos() {
        minimalImageViewWidthConstraint.priority = .almostInexist
        normalImageViewWidthConstraint.priority = .almostRequired
    }
    
    private func playVideo(at url: URL, mute: Bool) {
        playButton.isHidden = true
        if let player = playerView?.layer.player {
            if seekToZeroBeforePlay {
                player.seek(to: .zero)
                seekToZeroBeforePlay = false
            }
            player.isMuted = mute
            player.rate = 1
        } else {
            let item = AVPlayerItem(url: url)
            play(item: item, mute: mute)
        }
    }
    
    private func requestAndPlay(asset: PHAsset, mute: Bool) {
        playButton.isHidden = true
        if let player = playerView?.layer.player {
            if seekToZeroBeforePlay {
                player.seek(to: .zero)
                seekToZeroBeforePlay = false
            }
            player.isMuted = mute
            player.rate = 1
        } else {
            lastRequestId = PHImageManager.default().requestPlayerItem(forVideo: asset, options: offlineVideoRequestOptions) { [weak self] (item, info) in
                let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
                guard !isCancelled else {
                    return
                }
                DispatchQueue.main.async {
                    if let item = item {
                        self?.play(item: item, mute: mute)
                    } else {
                        self?.requestRemoteVideoAssetAndPlay(asset: asset, mute: mute)
                    }
                }
            }
        }
    }
    
    private func requestRemoteVideoAssetAndPlay(asset: PHAsset, mute: Bool) {
        activityIndicator.startAnimating()
        lastRequestId = PHImageManager.default().requestPlayerItem(forVideo: asset, options: onlineVideoRequestOptions) { [weak self] (item, info) in
            let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
            guard !isCancelled, let item = item else {
                return
            }
            DispatchQueue.main.async {
                self?.play(item: item, mute: mute)
            }
        }
    }
    
    private func play(item: AVPlayerItem, mute: Bool) {
        let playerView = PlayerView(frame: contentView.bounds)
        playerView.backgroundColor = .clear
        contentView.insertSubview(playerView, aboveSubview: imageView)
        playerView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        self.playerView = playerView

        let player = AVPlayer(playerItem: item)
        player.isMuted = mute
        playerView.layer.player = player
        playerObservation?.invalidate()
        playerObservation = player.observe(\.timeControlStatus) { [weak self] (player, change) in
            guard let weakSelf = self else {
                return
            }
            switch player.timeControlStatus {
            case .playing:
                weakSelf.playButton.isHidden = true
                weakSelf.pauseButton.isHidden = false
                weakSelf.activityIndicator.stopAnimating()
                weakSelf.updateVideoThumbnailMaskLayer()
            case .paused:
                weakSelf.playButton.isHidden = false
                weakSelf.pauseButton.isHidden = true
            default:
                break
            }
        }
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(playerItemDidPlayToEndTime),
                           name: Notification.Name.AVPlayerItemDidPlayToEndTime,
                           object: item)
        
        player.play()
    }
    
    private func loadAnimatedImage(asset: PHAsset) {
        lastRequestId = PHImageManager.default().requestImageDataAndOrientation(for: asset, options: imageRequestOptions, resultHandler: { [weak self] (data, uti, orientation, info) in
            guard let uti = uti, UTTypeConformsTo(uti as CFString, kUTTypeGIF) else {
                return
            }
            guard let data = data, let image = SDAnimatedImage(data: data) else {
                return
            }
            self?.imageView.image = image
        })
    }
    
    private func updateVideoThumbnailMaskLayer() {
        guard let playerLayer = playerView?.layer else {
            imageView.layer.mask = nil
            return
        }
        let videoRect = playerLayer.videoRect
        let converted = playerLayer.convert(videoRect, to: imageView.layer)
        guard converted != .zero else {
            imageView.layer.mask = nil
            return
        }
        videoThumbnailMaskLayer.frame = converted
        imageView.layer.mask = videoThumbnailMaskLayer
    }
    
}
