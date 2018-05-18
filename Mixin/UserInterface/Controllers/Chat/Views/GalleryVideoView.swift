import Foundation
import AVKit

class GalleryVideoView: UIView {
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    override var layer: AVPlayerLayer {
        return super.layer as! AVPlayerLayer
    }
    
    private let player: AVQueuePlayer = AVQueuePlayer()
    private let playButton: UIButton = UIButton(type: .custom)
    private let unplayableHintImageView = UIImageView(image: #imageLiteral(resourceName: "ic_file_expired"))
    private let thumbnailImageView = UIImageView()
    private let playableKey = "playable"
    
    private var url: URL?
    private var looper: AVPlayerLooper?
    
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
        playButton.center = center
        unplayableHintImageView.center = center
        thumbnailImageView.frame = bounds
    }
    
    func loadVideo(url: URL, playAfterLoaded: Bool, thumbnail: UIImage?) {
        if url != self.url {
            self.url = url
            let item = AVPlayerItem(url: url)
            if item.asset.statusOfValue(forKey: playableKey, error: nil) == .loaded {
                loadItem(item, playAfterLoaded: playAfterLoaded, thumbnail: thumbnail)
            } else {
                item.asset.loadValuesAsynchronously(forKeys: [playableKey], completionHandler: {
                    guard url == self.url else {
                        return
                    }
                    DispatchQueue.main.async {
                        guard url == self.url else {
                            return
                        }
                        self.loadItem(item, playAfterLoaded: playAfterLoaded, thumbnail: thumbnail)
                    }
                })
            }
        } else {
            playButton.isHidden = playAfterLoaded
            if playAfterLoaded, player.timeControlStatus != .playing, let item = player.currentItem, item.asset.isPlayable {
                player.play()
            }
        }
    }
    
    func pause(hidePlayButton: Bool) {
        playButton.isHidden = hidePlayButton
        if player.timeControlStatus == .playing {
            player.pause()
        }
    }
    
    @objc func playAction(_ sender: Any) {
        switch player.timeControlStatus {
        case .paused:
            playButton.isHidden = true
            player.play()
        case .playing, .waitingToPlayAtSpecifiedRate:
            break
        }
    }
    
    private func prepare() {
        layer.player = player
        playButton.setImage(#imageLiteral(resourceName: "ic_play"), for: .normal)
        playButton.addTarget(self, action: #selector(playAction(_:)), for: .touchUpInside)
        playButton.isHidden = true
        playButton.bounds.size = CGSize(width: 60, height: 60)
        addSubview(playButton)
        thumbnailImageView.isHidden = true
        addSubview(thumbnailImageView)
        unplayableHintImageView.isHidden = true
        addSubview(unplayableHintImageView)
    }
    
    private func loadItem(_ item: AVPlayerItem, playAfterLoaded: Bool, thumbnail: UIImage?) {
        let isPlayable = item.asset.isPlayable
        unplayableHintImageView.isHidden = isPlayable
        thumbnailImageView.isHidden = isPlayable
        playButton.isHidden = !isPlayable || playAfterLoaded
        if isPlayable {
            player.replaceCurrentItem(with: item)
            looper = AVPlayerLooper(player: player, templateItem: item)
            if playAfterLoaded {
                player.play()
            }
        } else {
            thumbnailImageView.image = thumbnail
        }
    }
    
}
