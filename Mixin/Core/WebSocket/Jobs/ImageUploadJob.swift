import Foundation
import Photos

class ImageUploadJob: AttachmentUploadJob {
    
    override class func jobId(messageId: String) -> String {
        return "image-upload-\(messageId)"
    }
    
    override func execute() -> Bool {
        guard !isCancelled, AccountAPI.shared.didLogin else {
            return false
        }
        if message.mediaUrl != nil {
            return super.execute()
        } else if let localIdentifier = message.mediaLocalIdentifier {
            updateMessageMediaUrl(with: localIdentifier)
            if message.mediaUrl != nil {
                return super.execute()
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    private func updateMessageMediaUrl(with mediaLocalIdentifier: String) {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [mediaLocalIdentifier], options: nil).firstObject else {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .EXPIRED, conversationId: message.conversationId)
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
            self.message.mediaUrl = filename
        }
    }
    
}
