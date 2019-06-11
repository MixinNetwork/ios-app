import Foundation
import Photos
import CoreServices

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
        
        let filename = self.message.messageId + ExtensionName.jpeg.withDot
        let url = MixinFile.url(ofChatDirectory: .photos, filename: filename)
        
        let uti: CFString
        if let id = asset.value(forKey: "uniformTypeIdentifier") as? String {
            uti = id as CFString
        } else if let res = PHAssetResource.assetResources(for: asset).first {
            uti = res.uniformTypeIdentifier as CFString
        } else {
            uti = kUTTypeJPEG
        }
        
        var image: UIImage?
        var imageData: Data?
        if UTTypeConformsTo(uti, kUTTypeGIF) {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.isSynchronous = true
            PHImageManager.default().requestImageData(for: asset, options: options) { (data, uti, orientation, info) in
                imageData = data
            }
        } else {
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
        
        guard !isCancelled, let data = imageData else {
            return
        }
        do {
            try data.write(to: url)
            message.mediaUrl = filename
            message.mediaSize = FileManager.default.fileSize(url.path)
            if message.thumbImage == nil {
                let thumbnail = image ?? UIImage(data: data)
                message.thumbImage = thumbnail?.base64Thumbnail() ?? ""
            }
            
            guard !isCancelled else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            MixinDatabase.shared.insertOrReplace(objects: [message])
            let change = ConversationChange(conversationId: message.conversationId, action: .updateMessage(messageId: message.messageId))
            NotificationCenter.default.afterPostOnMain(name: .ConversationDidChange, object: change)
            message.mediaUrl = filename
        } catch {
            UIApplication.traceError(error)
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
    
}
