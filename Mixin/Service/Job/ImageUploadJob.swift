import Foundation
import CoreServices
import Alamofire
import MixinServices

class ImageUploadJob: AttachmentUploadJob {
    
    override class func jobId(messageId: String) -> String {
        return "image-upload-\(messageId)"
    }
    
    override func execute() -> Bool {
        guard !isCancelled, LoginManager.shared.isLoggedIn else {
            return false
        }
        if let mediaUrl = message.mediaUrl {
            downloadRemoteMediaIfNeeded(url: mediaUrl)
            return super.execute()
        } else {
            return false
        }
    }
    
    private func downloadRemoteMediaIfNeeded(url: String) {
        guard url.hasPrefix("http"), let url = URL(string: url) else {
            return
        }
        let filename = message.messageId + ExtensionName.gif.withDot
        let fileUrl = AttachmentContainer.url(for: .photos, filename: filename)
        
        var success = false
        let sema = DispatchSemaphore(value: 0)
        AF.download(url, to: { (_, _) in
            (fileUrl, [.removePreviousFile, .createIntermediateDirectories])
        }).response(completionHandler: { (response) in
            success = response.error == nil
            sema.signal()
        })
        sema.wait()
        
        guard !isCancelled && success else {
            try? FileManager.default.removeItem(at: fileUrl)
            return
        }
        if message.thumbImage == nil {
            let image = UIImage(contentsOfFile: fileUrl.path)
            message.thumbImage = image?.blurHash() ?? ""
        }

        guard !isCancelled else {
            try? FileManager.default.removeItem(at: fileUrl)
            return
        }
        updateMessage(filename: filename, url: url)
    }
    
    private func updateMessage(filename: String, url: URL, mediaWidth: Int? = nil, mediaHeight: Int? = nil) {
        let mediaSize = FileManager.default.fileSize(url.path)
        message.mediaUrl = filename
        message.mediaSize = mediaSize
        var assignments = [
            Message.column(of: .mediaUrl).set(to: filename),
            Message.column(of: .mediaSize).set(to: mediaSize)
        ]
        if let mediaWidth = mediaWidth {
            assignments.append(Message.column(of: .mediaWidth).set(to: mediaWidth))
            message.mediaWidth = mediaWidth
        }
        if let mediaHeight = mediaHeight {
            assignments.append(Message.column(of: .mediaHeight).set(to: mediaHeight))
            message.mediaHeight = mediaHeight
        }
        let change = ConversationChange(conversationId: message.conversationId,
                                        action: .updateMediaContent(messageId: message.messageId, message: message))
        MessageDAO.shared.updateMediaMessage(messageId: message.messageId, assignments: assignments) { _ in
            NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: change)
        }
    }
    
}
