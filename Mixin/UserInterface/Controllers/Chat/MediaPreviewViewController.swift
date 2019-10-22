import UIKit
import Photos
import YYImage
import CoreServices

final class MediaPreviewViewController: UIViewController {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var imageView: YYAnimatedImageView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var dismissButton: UIButton!
    
    @IBOutlet weak var stackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var minimalImageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var normalImageViewWidthConstraint: NSLayoutConstraint!
    
    var dataSource: ConversationDataSource?
    
    private var lastRequestId: PHImageRequestID?
    private var asset: PHAsset?
    private var playerView: PlayerView?
    private var playerObservation: NSKeyValueObservation?
    private var seekToZeroBeforePlay = false
    
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
        for case let label? in [sendButton.titleLabel, dismissButton.titleLabel] {
            label.set(font: .systemFont(ofSize: 19, weight: .medium), adjustForContentSize: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let id = lastRequestId {
            PHImageManager.default().cancelImageRequest(id)
        }
        playerView?.layer.player?.rate = 0
        playerObservation?.invalidate()
    }
    
    @available(iOS 11.0, *)
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
        AudioManager.shared.pause()
        playButton.isHidden = true
        if let player = playerView?.layer.player {
            if seekToZeroBeforePlay {
                player.seek(to: .zero)
                seekToZeroBeforePlay = false
            }
            player.rate = 1
        } else {
            lastRequestId = PHImageManager.default().requestPlayerItem(forVideo: asset, options: offlineVideoRequestOptions) { [weak self] (item, info) in
                let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
                guard !isCancelled else {
                    return
                }
                DispatchQueue.main.async {
                    if let item = item {
                        self?.play(item: item)
                    } else {
                        self?.requestRemoteVideoAssetAndPlay(asset: asset)
                    }
                }
            }
        }
    }
    
    @IBAction func pauseAction(_ sender: Any) {
        playerView?.layer.player?.pause()
    }
    
    @IBAction func sendAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        if let asset = asset {
            dataSource?.send(asset: asset)
        }
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    func load(asset: PHAsset) {
        self.asset = asset
        loadViewIfNeeded()
        activityIndicator.startAnimating()
        let targetSize = imageView.bounds.size * UIScreen.main.scale
        lastRequestId = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: imageRequestOptions) { [weak self] (image, info) in
            guard let weakSelf = self, let image = image else {
                return
            }
            let useMinimalImageViewSize = asset.mediaType == .image
                && CGFloat(asset.pixelWidth * 3) < targetSize.width
                && CGFloat(asset.pixelHeight * 3) < targetSize.height
            if useMinimalImageViewSize {
                weakSelf.minimalImageViewWidthConstraint.priority = .almostRequired
                weakSelf.normalImageViewWidthConstraint.priority = .almostInexist
            } else {
                weakSelf.minimalImageViewWidthConstraint.priority = .almostInexist
                weakSelf.normalImageViewWidthConstraint.priority = .almostRequired
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
    
    @objc private func playerItemDidPlayToEndTime() {
        DispatchQueue.main.async {
            self.seekToZeroBeforePlay = true
        }
    }
    
    private func requestRemoteVideoAssetAndPlay(asset: PHAsset) {
        activityIndicator.startAnimating()
        lastRequestId = PHImageManager.default().requestPlayerItem(forVideo: asset, options: onlineVideoRequestOptions) { [weak self] (item, info) in
            let isCancelled = info?[PHImageCancelledKey] as? Bool ?? false
            guard !isCancelled, let item = item else {
                return
            }
            DispatchQueue.main.async {
                self?.play(item: item)
            }
        }
    }
    
    private func play(item: AVPlayerItem) {
        let playerView = PlayerView(frame: contentView.bounds)
        playerView.backgroundColor = .clear
        contentView.insertSubview(playerView, aboveSubview: imageView)
        playerView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        self.playerView = playerView

        let player = AVPlayer(playerItem: item)
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
        lastRequestId = PHImageManager.default().requestImageData(for: asset, options: imageRequestOptions, resultHandler: { [weak self] (data, uti, orientation, info) in
            guard let uti = uti, UTTypeConformsTo(uti as CFString, kUTTypeGIF) else {
                return
            }
            guard let data = data, let image = YYImage(data: data) else {
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
