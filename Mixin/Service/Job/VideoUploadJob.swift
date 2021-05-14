import Foundation
import Photos
import MixinServices

class VideoUploadJob: AttachmentUploadJob {
    
    override var fileUrl: URL? {
        guard let mediaUrl = message.mediaUrl else {
            return nil
        }
        return AttachmentContainer.url(for: .videos, filename: mediaUrl)
    }
    
    override class func jobId(messageId: String) -> String {
        return "video-upload-\(messageId)"
    }
    
    override func execute() -> Bool {
        guard !isCancelled, LoginManager.shared.isLoggedIn else {
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
        guard let phAsset = PHAsset.fetchAssets(withLocalIdentifiers: [mediaLocalIdentifier], options: nil).firstObject else {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .EXPIRED, conversationId: message.conversationId)
            return
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var avAsset: AVAsset?
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { (asset, audioMix, info) in
            avAsset = asset
            semaphore.signal()
        }
        semaphore.wait()
        
        guard !isCancelled, let asset = avAsset else {
            return
        }
        let filename = message.messageId
        let videoFilename = filename + ExtensionName.mp4.withDot
        let videoUrl = AttachmentContainer.url(for: .videos, filename: videoFilename)
        let exportSession = AssetExportSession(asset: asset, outputURL: videoUrl)
        exportSession.exportAsynchronously {
            semaphore.signal()
        }
        semaphore.wait()
        
        guard !isCancelled, exportSession.status == .completed else {
            try? FileManager.default.removeItem(at: videoUrl)
            return
        }
        let thumbnail = UIImage(withFirstFrameOf: asset)
        let thumbnailUrl = AttachmentContainer.videoThumbnailURL(videoFilename: videoFilename)
        thumbnail?.saveToFile(path: thumbnailUrl)
        let mediaSize = FileManager.default.fileSize(videoUrl.path)
        let mediaDuration = Int64(phAsset.duration * 1000)
        message.mediaUrl = videoFilename
        message.mediaDuration = mediaDuration
        message.mediaSize = mediaSize
        let assignments = [
            Message.column(of: .mediaUrl).set(to: videoFilename),
            Message.column(of: .mediaSize).set(to: mediaSize),
            Message.column(of: .mediaDuration).set(to: mediaDuration)
        ]
        let change = ConversationChange(conversationId: message.conversationId,
                                        action: .updateMediaContent(messageId: message.messageId, message: message))
        MessageDAO.shared.updateMediaMessage(messageId: message.messageId, assignments: assignments) { _ in
            NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: change)
        }
    }
    
}
