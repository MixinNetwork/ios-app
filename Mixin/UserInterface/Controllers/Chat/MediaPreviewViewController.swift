import UIKit
import Photos
import AVKit

class MediaPreviewViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    
    private var lastRequestId: PHImageRequestID?
    private var lastAssetIdentifier: String?
    private var playerController: AVPlayerViewController?
    
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
            imageView.isHidden = false
            PHImageManager.default().requestImage(for: asset, targetSize: imageView.bounds.size, contentMode: .aspectFit, options: nil) { [weak self] (image, _) in
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
