import UIKit

struct GalleryItem: Equatable {
    
    let messageId: String
    let url: URL?
    let size: CGSize
    let thumbnail: UIImage?
    let createdAt: String
    var mediaStatus: MediaStatus?
    
    init?(message: Message) {
        guard message.category == MessageCategory.SIGNAL_IMAGE.rawValue || message.category == MessageCategory.PLAIN_IMAGE.rawValue else {
            return nil
        }
        self.messageId = message.messageId
        if let mediaUrl = message.mediaUrl {
            self.url = MixinFile.chatPhotosUrl(mediaUrl)
        } else {
            self.url = nil
        }
        let width = max(1, message.mediaWidth ?? 1)
        let height = max(1, message.mediaHeight ?? 1)
        self.size = CGSize(width: width, height: height)
        if let thumbImage = message.thumbImage, let data = Data(base64Encoded: thumbImage) {
            self.thumbnail = UIImage(data: data)
        } else {
            self.thumbnail = nil
        }
        self.createdAt = message.createdAt
        self.mediaStatus = MediaStatus(rawValue: message.mediaStatus ?? "")
    }
    
    init?(message: MessageItem) {
        guard message.category == MessageCategory.SIGNAL_IMAGE.rawValue || message.category == MessageCategory.PLAIN_IMAGE.rawValue else {
            return nil
        }
        self.messageId = message.messageId
        if let mediaUrl = message.mediaUrl {
            self.url = MixinFile.chatPhotosUrl(mediaUrl)
        } else {
            self.url = nil
        }
        let width = max(1, message.mediaWidth ?? 1)
        let height = max(1, message.mediaHeight ?? 1)
        self.size = CGSize(width: width, height: height)
        if let thumbImage = message.thumbImage, let data = Data(base64Encoded: thumbImage) {
            self.thumbnail = UIImage(data: data)
        } else {
            self.thumbnail = nil
        }
        self.createdAt = message.createdAt
        self.mediaStatus = MediaStatus(rawValue: message.mediaStatus ?? "")
    }
    
    static func ==(lhs: GalleryItem, rhs: GalleryItem) -> Bool {
        return lhs.messageId == rhs.messageId
            && lhs.url == rhs.url
            && lhs.mediaStatus == rhs.mediaStatus
    }
    
}
