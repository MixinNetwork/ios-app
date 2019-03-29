import Foundation
import Photos

class AssetRequestJob: BaseJob {
    
    var message: Message
    
    private(set) var asset: PHAsset?
    
    init(message: Message) {
        self.message = message
        super.init()
    }
    
    class func jobId(messageId: String) -> String {
        return "asset-request-" + messageId
    }
    
    override func getJobId() -> String {
        return AssetRequestJob.jobId(messageId: message.messageId)
    }
    
    override func main() {
        guard !isCancelled, AccountAPI.shared.didLogin, let localIdentifier = message.mediaLocalIdentifier else {
            return
        }
        asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }
    
}
