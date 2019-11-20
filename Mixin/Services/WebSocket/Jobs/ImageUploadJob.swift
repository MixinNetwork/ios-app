import Foundation
import Photos
import CoreServices
import Alamofire
import WCDBSwift

class ImageUploadJob: AttachmentUploadJob {
    
    override class func jobId(messageId: String) -> String {
        return "image-upload-\(messageId)"
    }
    
    override func execute() -> Bool {
        guard !isCancelled, AccountAPI.shared.didLogin else {
            return false
        }
        if let mediaUrl = message.mediaUrl {
            downloadRemoteMediaIfNeeded(url: mediaUrl)
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
    
    private func downloadRemoteMediaIfNeeded(url: String) {
        guard url.hasPrefix("http"), let url = URL(string: url) else {
            return
        }
        let filename = message.messageId + ExtensionName.gif.withDot
        let fileUrl = MixinFile.url(ofChatDirectory: .photos, filename: filename)
        
        var success = false
        let sema = DispatchSemaphore(value: 0)
        Alamofire.download(url, to: { (_, _) in
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
            message.thumbImage = image?.base64Thumbnail() ?? ""
        }

        guard !isCancelled else {
            try? FileManager.default.removeItem(at: fileUrl)
            return
        }
        updateMediaUrlAndPostNotification(filename: filename, url: url)
    }
    
    private func updateMessageMediaUrl(with mediaLocalIdentifier: String) {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [mediaLocalIdentifier], options: nil).firstObject else {
            MessageDAO.shared.updateMediaStatus(messageId: message.messageId, status: .EXPIRED, conversationId: message.conversationId)
            return
        }
        
        let uti = asset.uniformTypeIdentifier ?? kUTTypeJPEG
        let extensionName: String
        var image: UIImage?
        var imageData: Data?
        if UTTypeConformsTo(uti, kUTTypeGIF) {
            extensionName = ExtensionName.gif.rawValue
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.isSynchronous = true
            PHImageManager.default().requestImageData(for: asset, options: options) { (data, uti, orientation, info) in
                imageData = data
            }
        } else {
            extensionName = ExtensionName.jpeg.rawValue
            let options = PHImageRequestOptions()
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true
            options.isSynchronous = true
            let targetSize = size(for: asset)
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { (result, info) in
                image = result
            }
            imageData = image?.jpegData(compressionQuality: jpegCompressionQuality)
        }
        
        let filename = "\(message.messageId).\(extensionName)"
        let url = MixinFile.url(ofChatDirectory: .photos, filename: filename)
        
        guard !isCancelled, let data = imageData else {
            return
        }
        do {
            try data.write(to: url)
            if message.thumbImage == nil {
                let thumbnail = image ?? UIImage(data: data)
                message.thumbImage = thumbnail?.base64Thumbnail() ?? ""
            }
            guard !isCancelled else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            updateMediaUrlAndPostNotification(filename: filename, url: url)
        } catch {
            Reporter.report(error: error)
        }
    }
    
    private func size(for asset: PHAsset) -> CGSize {
        let maxShortSideLength = 1440
        guard min(asset.pixelWidth, asset.pixelHeight) >= maxShortSideLength else {
            return CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        }
        let maxLongSideLength: Double = 1920
        let scale = Double(asset.pixelWidth) / Double(asset.pixelHeight)
        let width = Int(scale > 1 ? maxLongSideLength : maxLongSideLength * scale)
        let height = Int(scale > 1 ? maxLongSideLength / scale : maxLongSideLength)
        return CGSize(width: width, height: height)
    }
    
    private func updateMediaUrlAndPostNotification(filename: String, url: URL) {
        let mediaSize = FileManager.default.fileSize(url.path)
        message.mediaUrl = filename
        message.mediaSize = mediaSize
        MessageDAO.shared.updateMediaMessage(messageId: message.messageId, keyValues: [(Message.Properties.mediaUrl, filename), (Message.Properties.mediaSize, mediaSize)])
        let change = ConversationChange(conversationId: message.conversationId,
                                        action: .updateMediaContent(messageId: message.messageId, message: message))
        NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
    }
    
}
