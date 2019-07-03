import UIKit
import AVFoundation

class FloatVideoPlayer {
    
    let view = FloatPlayerView()
    
    func play(url: URL, presentationRatio ratio: CGFloat) {
        guard let window = UIApplication.shared.keyWindow else {
            return
        }
        view.sizeToFit(window: window, byRatio: ratio)
        if view.window != window {
            view.removeFromSuperview()
            window.addSubview(view)
        }
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: [NSExpression(forKeyPath: \AVAsset.isPlayable).keyPath])
        print(item.asset.isPlayable)
        view.player.replaceCurrentItem(with: item)
        view.player.play()
    }
    
}
