import Foundation
import Photos
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
        let options: PHImageRequestOptions = {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.isSynchronous = true
            return options
        }()
        
        let extensionName: String
        var image: UIImage?
        var imageData: Data?
        if UTTypeConformsTo(uti, kUTTypeGIF) {
            extensionName = ExtensionName.gif.rawValue
            PHImageManager.default().requestImageData(for: asset, options: options) { (data, uti, orientation, info) in
                imageData = data
            }
        } else if imageWithRatioMaybeAnArticle(CGSize(width: asset.pixelWidth, height: asset.pixelHeight)) {
            extensionName = ExtensionName.jpeg.rawValue
            if UTTypeConformsTo(uti, kUTTypeJPEG) {
                PHImageManager.default().requestImageData(for: asset, options: options) { (data, _, _, _) in
                    imageData = data
                }
            } else {
                options.deliveryMode = .highQualityFormat
                PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { (rawImage, _) in
                    guard let rawImage = rawImage else {
                        return
                    }
                    (image, imageData) = ImageUploadSanitizer.sanitizedImage(from: rawImage)
                }
            }
        } else {
            extensionName = ExtensionName.jpeg.rawValue
            options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImage(for: asset, targetSize: ImageUploadSanitizer.maxSize, contentMode: .aspectFit, options: options) { (rawImage, _) in
                guard let rawImage = rawImage else {
                    return
                }
                (image, imageData) = ImageUploadSanitizer.sanitizedImage(from: rawImage)
            }
        }
        
        let filename = "\(message.messageId).\(extensionName)"
        let url = AttachmentContainer.url(for: .photos, filename: filename)
        
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
                try FileManager.default.removeItem(at: url)
                return
            }
            updateMediaUrlAndPostNotification(filename: filename, url: url)
        } catch {
            reporter.report(error: error)
        }
    }
    
    private func updateMediaUrlAndPostNotification(filename: String, url: URL) {
        let mediaSize = FileManager.default.fileSize(url.path)
        message.mediaUrl = filename
        message.mediaSize = mediaSize
        let assignments = [
            Message.column(of: .mediaUrl).set(to: filename),
            Message.column(of: .mediaSize).set(to: mediaSize)
        ]
        let change = ConversationChange(conversationId: message.conversationId,
                                        action: .updateMediaContent(messageId: message.messageId, message: message))
        MessageDAO.shared.updateMediaMessage(messageId: message.messageId, assignments: assignments) { _ in
            NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: change)
        }
    }
    
}
