import Foundation
import Photos

class VideoAssetRequestJob: AssetRequestJob {
    
    private(set) var avAsset: AVAsset?
    
    override func main() {
        super.main()
        guard !isCancelled, AccountAPI.shared.didLogin, let asset = asset else {
            return
        }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        let semaphore = DispatchSemaphore(value: 0)
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { (avAsset, audioMix, info) in
            if !self.isCancelled {
                self.avAsset = avAsset
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
    
}
