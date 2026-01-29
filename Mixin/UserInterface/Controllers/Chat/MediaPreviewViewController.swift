import AVFoundation
import UIKit
import UniformTypeIdentifiers
import SDWebImage
import MixinServices

final class MediaPreviewViewController: UIViewController {
    
    enum Resource {
        case provider(NSItemProvider)
        case image(UIImage)
    }
    
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
    
    private let resource: Resource
    
    private var asset: Asset?
    private var playerView: PlayerView?
    private var playerObservation: NSKeyValueObservation?
    private var seekToZeroBeforePlay = false
    
    private lazy var videoThumbnailMaskLayer: CALayer = {
        let layer = CALayer()
        layer.backgroundColor = UIColor.white.cgColor
        return layer
    }()
    
    init(resource: Resource) {
        self.resource = resource
        let nib = R.nib.mediaPreviewView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    static func canLoad(itemProvider: NSItemProvider) -> Bool {
        itemProvider.hasItemConformingToTypeIdentifier(UTType.gif.identifier)
            || itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            || itemProvider.canLoadObject(ofClass: UIImage.self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.autoPlayAnimatedImage = true
        activityIndicator.style = .large
        activityIndicator.startAnimating()
        switch resource {
        case .provider(let provider):
            load(itemProvider: provider)
        case .image(let rawImage):
            DispatchQueue.global().async { [weak self] in
                let image = ImageUploadSanitizer.sanitizedImage(from: rawImage).image
                DispatchQueue.main.async {
                    if let image {
                        self?.load(image: image)
                    } else {
                        showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_share_content())
                        self?.presentingViewController?.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
    
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession, reason: AudioSession.InterruptionReason) {
        pauseAction(audioSession)
    }
    
}

extension MediaPreviewViewController {
    
    private enum Asset {
        case gif(URL, UIImage)
        case video(URL)
        case image(UIImage)
    }
    
    enum Error: Swift.Error {
        case loadFileRepresentation(Swift.Error?)
        case copyItem(Swift.Error)
    }
    
    private func load(image: UIImage) {
        asset = .image(image)
        let assetPixelSize = image.size * image.scale
        updateImageViewSizeForImages(with: assetPixelSize)
        imageView.image = image
        activityIndicator.stopAnimating()
        playButton.isHidden = true
        view.layoutIfNeeded()
    }
    
    private func load(itemProvider: NSItemProvider) {
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.gif.identifier) {
            copyFile(from: itemProvider, identifier: UTType.gif.identifier) { _ in
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
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            // A video file in temp directory or with no extension name is not playable
            guard let document = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            copyFile(from: itemProvider, identifier: UTType.movie.identifier) { source in
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
                let sanitizedImage: UIImage? = if let rawImage = rawImage as? UIImage {
                    ImageUploadSanitizer.sanitizedImage(from: rawImage).image
                } else {
                    nil
                }
                DispatchQueue.main.async {
                    if let sanitizedImage {
                        self?.load(image: sanitizedImage)
                    } else {
                        showAutoHiddenHud(style: .error, text: R.string.localizable.unable_to_share_content())
                        self?.presentingViewController?.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
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
