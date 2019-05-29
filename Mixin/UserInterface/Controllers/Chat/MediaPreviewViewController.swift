import UIKit
import Photos
import AVKit

class MediaPreviewViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var changeContentModeWrapperView: UIView!
    
    @IBOutlet weak var changeContentModeWrapperWidthConstraint: NSLayoutConstraint!
    
    private var lastRequestId: PHImageRequestID?
    private var lastAssetIdentifier: String?
    private var playerController: AVPlayerViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        changeContentModeWrapperView.clipsToBounds = true
        changeContentModeWrapperView.layer.cornerRadius = changeContentModeWrapperWidthConstraint.constant / 2
        changeContentModeWrapperView.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
        changeContentModeWrapperView.layer.borderWidth = 1 / UIScreen.main.scale
    }
    
    @IBAction func changeContentModeAction(_ sender: Any) {
        if !imageView.isHidden {
            let isAspectFill = imageView.contentMode == .scaleAspectFill
            imageView.contentMode = isAspectFill ? .scaleAspectFit : .scaleAspectFill
        }
        if let playerController = playerController, !playerController.view.isHidden {
            let isAspectFill = playerController.videoGravity == .resizeAspectFill
            playerController.videoGravity = isAspectFill ? .resizeAspect : .resizeAspectFill
        }
    }
    
    func load(asset: PHAsset) {
        guard asset.localIdentifier != lastAssetIdentifier else {
            return
        }
        if let id = lastRequestId {
            PHImageManager.default().cancelImageRequest(id)
            PHCachingImageManager.default().cancelImageRequest(id)
        }
        if let playerController = playerController {
            playerController.player?.rate = 0
        }
        if asset.mediaType == .image {
            if let playerController = playerController {
                playerController.view.isHidden = true
            }
            imageView.image = nil
            imageView.contentMode = .scaleAspectFill
            imageView.isHidden = false
            PHImageManager.default().requestImage(for: asset, targetSize: imageView.bounds.size, contentMode: .aspectFill, options: nil) { [weak self] (image, _) in
                DispatchQueue.main.async {
                    guard let weakSelf = self else {
                        return
                    }
                    weakSelf.imageView.image = image
                    weakSelf.lastRequestId = nil
                    weakSelf.lastAssetIdentifier = asset.localIdentifier
                }
            }
        } else if asset.mediaType == .video {
            imageView.isHidden = true
            if let playerController = playerController {
                playerController.view.isHidden = false
                UIView.performWithoutAnimation {
                    playerController.videoGravity = .resizeAspectFill
                }
            } else {
                let controller = AVPlayerViewController()
                controller.showsPlaybackControls = false
                controller.videoGravity = .resizeAspectFill
                addChild(controller)
                contentView.insertSubview(controller.view, belowSubview: changeContentModeWrapperView)
                controller.view.snp.makeConstraints({ (make) in
                    make.edges.equalToSuperview()
                })
                controller.view.backgroundColor = .clear
                controller.didMove(toParent: self)
                playerController = controller
            }
            PHCachingImageManager.default().requestAVAsset(forVideo: asset, options: nil) { [weak self] (avAsset, _, _) in
                DispatchQueue.main.async {
                    guard let weakSelf = self, let playerController = weakSelf.playerController, let avAsset = avAsset else {
                        return
                    }
                    let item = AVPlayerItem(asset: avAsset)
                    let player = AVPlayer(playerItem: item)
                    playerController.player = player
                    player.play()
                    weakSelf.lastRequestId = nil
                    weakSelf.lastAssetIdentifier = asset.localIdentifier
                }
            }
        }
    }
    
    func stopVideoPreviewIfNeeded() {
        guard let player = playerController?.player else {
            return
        }
        player.rate = 0
    }
    
}
