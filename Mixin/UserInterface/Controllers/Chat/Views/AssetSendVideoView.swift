import UIKit
import AVFoundation

class AssetSendVideoView: UIView {
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    override var layer: AVPlayerLayer {
        return super.layer as! AVPlayerLayer
    }
    
    let player = AVPlayer()
    private let unplayableHintImageView = UIImageView(image: R.image.ic_file_expired()!)
    private let thumbnailImageView = UIImageView()
    private let playableKey = "playable"
    
    private var url: URL?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        unplayableHintImageView.center = center
        thumbnailImageView.frame = bounds
    }
    
    func loadVideo(asset: AVAsset, thumbnail: UIImage?) {
        let item = AVPlayerItem(asset: asset)
        if item.asset.statusOfValue(forKey: playableKey, error: nil) == .loaded {
            loadItem(item, thumbnail: thumbnail)
        } else {
            item.asset.loadValuesAsynchronously(forKeys: [playableKey], completionHandler: {
                DispatchQueue.main.async {
                    self.loadItem(item, thumbnail: thumbnail)
                }
            })
        }
    }
    
    private func prepare() {
        layer.player = player
        addSubview(thumbnailImageView)
        unplayableHintImageView.isHidden = true
        addSubview(unplayableHintImageView)
    }
    
    private func loadItem(_ item: AVPlayerItem, thumbnail: UIImage?) {
        let isPlayable = item.asset.isPlayable
        unplayableHintImageView.isHidden = isPlayable
        thumbnailImageView.isHidden = isPlayable
        if isPlayable {
            player.replaceCurrentItem(with: item)
        } else {
            thumbnailImageView.image = thumbnail
        }
    }
    
    func pause() {
        guard player.currentItem != nil else {
            return
        }
        player.pause()
    }
    
    func play() {
        guard player.currentItem != nil, player.status == .readyToPlay else {
            return
        }
        player.play()
    }
    
    func isPlaying() -> Bool {
        guard player.currentItem != nil, player.status == .readyToPlay else {
            return false
        }
        return player.rate > 0
    }
    
    func seek(to: CMTime) {
        guard player.currentItem != nil, player.status == .readyToPlay else {
            return
        }
        player.seek(to: to)
    }
    
}
