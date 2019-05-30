import UIKit
import Photos
import AVKit

class MediaPreviewViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    private var lastRequestId: PHImageRequestID?
    private var lastAssetIdentifier: String?
    private var playerController: AVPlayerViewController?
    
    private lazy var offlineImageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        return options
    }()
    private lazy var onlineImageRequestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
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
    
    func load(asset: PHAsset) {
        guard asset.localIdentifier != lastAssetIdentifier else {
            return
        }
        if let id = lastRequestId {
            PHImageManager.default().cancelImageRequest(id)
        }
        if let playerController = playerController {
            playerController.player?.rate = 0
        }
        activityIndicator.stopAnimating()
        if asset.mediaType == .image {
            loadImage(asset: asset)
        } else if asset.mediaType == .video {
            loadVideo(asset: asset)
        }
    }
    
    func stopVideoPreviewIfNeeded() {
        guard let player = playerController?.player else {
            return
        }
        player.rate = 0
    }
    
    private func loadImage(asset: PHAsset) {
        if let playerController = playerController {
            playerController.view.isHidden = true
        }
        imageView.image = nil
        imageView.isHidden = false
        requestImageAndDisplay(asset: asset, allowNetworkAccess: false)
    }
    
    private func loadVideo(asset: PHAsset) {
        imageView.isHidden = true
        if let playerController = playerController {
            playerController.player = nil
            playerController.view.isHidden = false
        } else {
            let controller = AVPlayerViewController()
            controller.showsPlaybackControls = false
            addChild(controller)
            contentView.addSubview(controller.view)
            controller.view.snp.makeConstraints({ (make) in
                make.edges.equalToSuperview()
            })
            controller.view.backgroundColor = .clear
            controller.didMove(toParent: self)
            playerController = controller
        }
        requestVideoAndPlay(asset: asset, allowNetworkAccess: false)
    }
    
    private func requestImageAndDisplay(asset: PHAsset, allowNetworkAccess: Bool) {
        guard !allowNetworkAccess || NetworkManager.shared.isReachable else {
            return
        }
        let options = allowNetworkAccess ? onlineImageRequestOptions : offlineImageRequestOptions
        PHImageManager.default().requestImage(for: asset, targetSize: imageView.bounds.size, contentMode: .aspectFit, options: options) { [weak self] (image, info) in
            guard let weakSelf = self else {
                return
            }
            if let image = image {
                weakSelf.imageView.image = image
                weakSelf.lastRequestId = nil
                weakSelf.lastAssetIdentifier = asset.localIdentifier
                weakSelf.activityIndicator.stopAnimating()
            } else {
                weakSelf.activityIndicator.startAnimating()
                weakSelf.requestImageAndDisplay(asset: asset, allowNetworkAccess: true)
            }
        }
    }
    
    private func requestVideoAndPlay(asset: PHAsset, allowNetworkAccess: Bool) {
        guard !allowNetworkAccess || NetworkManager.shared.isReachable else {
            return
        }
        let options = allowNetworkAccess ? onlineVideoRequestOptions : offlineVideoRequestOptions
        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { [weak self] (item, info) in
            DispatchQueue.main.async {
                guard let weakSelf = self, let playerController = weakSelf.playerController else {
                    return
                }
                if let item = item {
                    let player = AVPlayer(playerItem: item)
                    playerController.player = player
                    player.play()
                    weakSelf.activityIndicator.stopAnimating()
                    weakSelf.lastRequestId = nil
                    weakSelf.lastAssetIdentifier = asset.localIdentifier
                } else {
                    weakSelf.activityIndicator.startAnimating()
                    weakSelf.requestVideoAndPlay(asset: asset, allowNetworkAccess: true)
                }
            }
        }
    }
    
}
