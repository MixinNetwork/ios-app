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
        playButton.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    func loadVideo(url: URL, playAfterLoaded: Bool) {
        if url != self.url {
            self.url = url
            let item = AVPlayerItem(url: url)
            if item.asset.isPlayable {
                player.replaceCurrentItem(with: item)
                looper = AVPlayerLooper(player: player, templateItem: item)
                if playAfterLoaded {
                    player.play()
                    playButton.isHidden = true
                } else {
                    playButton.isHidden = false
                }
            }
        } else {
            if playAfterLoaded {
                if player.timeControlStatus != .playing {
                    playButton.isHidden = true
                    if let item = player.currentItem, item.asset.isPlayable {
                        player.play()
                    } else {
                        // Unable to play
                    }
                }
            } else {
                playButton.isHidden = false
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
    }
    
}
