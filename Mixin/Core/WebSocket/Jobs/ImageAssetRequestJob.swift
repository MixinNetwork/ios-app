import Foundation
import Photos

class ImageAssetRequestJob: AssetRequestJob {
    
    private(set) var fileUrl: URL?
    
    override func main() {
        super.main()
        guard !isCancelled, AccountAPI.shared.didLogin, let asset = asset else {
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        let targetSize = CGSize(width: CGFloat(message.mediaWidth ?? 1920),
                                height: CGFloat(message.mediaHeight ?? 1920))
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { (image, info) in
            guard let image = image, !self.isCancelled else {
                return
            }
            let filename = self.message.messageId + ExtensionName.jpeg.withDot
            let url = MixinFile.url(ofChatDirectory: .photos, filename: filename)
            image.saveToFile(path: url)
            let mediaSize = FileManager.default.fileSize(url.path)
            self.message.mediaUrl = filename
            self.message.mediaSize = mediaSize
            MixinDatabase.shared.insertOrReplace(objects: [self.message])
            let change = ConversationChange(conversationId: self.message.conversationId, action: .updateMessage(messageId: self.message.messageId))
            NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
            self.fileUrl = url
        }
    }
    
}
