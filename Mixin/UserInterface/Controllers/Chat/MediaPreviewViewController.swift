import UIKit
import Photos
import AVKit

final class MediaPreviewViewController: UIViewController {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    @IBOutlet weak var playButton: UIButton!
    
    @IBOutlet weak var stackViewBottomConstraint: NSLayoutConstraint!
    
    var dataSource: ConversationDataSource?
    
    private var lastRequestId: PHImageRequestID?
    private var lastAssetIdentifier: String?
    private var asset: PHAsset?
    
    private var playerView: PlayerView?
    private var playerObservation: NSKeyValueObservation?
    
    private lazy var imageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        return options
    }()
    private lazy var videoRequestOptions: PHVideoRequestOptions = {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        options.deliveryMode = .mediumQualityFormat
        options.progressHandler = nil
        return options
    }()
    
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
        playButton.isHidden = true
        activityIndicator.startAnimating()
        lastRequestId = PHImageManager.default().requestPlayerItem(forVideo: asset, options: videoRequestOptions) { [weak self] (item, info) in
            DispatchQueue.main.async {
                guard let weakSelf = self, let item = item else {
                    return
                }
                weakSelf.lastRequestId = nil
                weakSelf.play(item: item)
            }
        }
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
        guard asset.localIdentifier != lastAssetIdentifier else {
            return
        }
        loadViewIfNeeded()
        activityIndicator.startAnimating()
        let targetSize = imageView.bounds.size * UIScreen.main.scale
        lastRequestId = PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: imageRequestOptions) { [weak self] (image, info) in
            guard let weakSelf = self, let image = image else {
                return
            }
            weakSelf.imageView.image = image
            weakSelf.lastRequestId = nil
            weakSelf.lastAssetIdentifier = asset.localIdentifier
            weakSelf.activityIndicator.stopAnimating()
            weakSelf.playButton.isHidden = asset.mediaType != .video
        }
    }
    
    private func play(item: AVPlayerItem) {
        let playerView: PlayerView
        if let view = self.playerView {
            playerView = view
        } else {
            playerView = PlayerView(frame: contentView.bounds)
            playerView.backgroundColor = .clear
            contentView.insertSubview(playerView, belowSubview: imageView)
            playerView.snp.makeConstraints({ (make) in
                make.edges.equalToSuperview()
            })
            self.playerView = playerView
        }
        
        let player: AVPlayer
        if let currentPlayer = playerView.layer.player, currentPlayer.currentItem == item {
            player = currentPlayer
            player.seek(to: .zero)
        } else {
            player = AVPlayer(playerItem: item)
            playerView.layer.player = player
            playerObservation?.invalidate()
            playerObservation = player.observe(\.timeControlStatus) { [weak self] (player, change) in
                guard let weakSelf = self else {
                    return
                }
                switch player.timeControlStatus {
                case .playing:
                    weakSelf.imageView.isHidden = true
                    weakSelf.playButton.isHidden = true
                    weakSelf.activityIndicator.stopAnimating()
                case .paused:
                    weakSelf.imageView.isHidden = false
                    weakSelf.playButton.isHidden = false
                default:
                    break
                }
            }
        }
        
        player.play()
    }
    
    private final class PlayerView: UIView {
        
        override static var layerClass: AnyClass {
            return AVPlayerLayer.self
        }
        
        override var layer: AVPlayerLayer {
            return super.layer as! AVPlayerLayer
        }
        
    }
    
}
