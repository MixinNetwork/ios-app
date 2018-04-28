import UIKit

struct Photo: Equatable {
    
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
        self.size = CGSize(width: message.mediaWidth ?? 1, height: message.mediaHeight ?? 1)
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
        self.size = CGSize(width: message.mediaWidth ?? 1, height: message.mediaHeight ?? 1)
        if let thumbImage = message.thumbImage, let data = Data(base64Encoded: thumbImage) {
            self.thumbnail = UIImage(data: data)
        } else {
            self.thumbnail = nil
        }
        self.createdAt = message.createdAt
        self.mediaStatus = MediaStatus(rawValue: message.mediaStatus ?? "")
    }
    
    static func ==(lhs: Photo, rhs: Photo) -> Bool {
        return lhs.messageId == rhs.messageId
            && lhs.url == rhs.url
            && lhs.mediaStatus == rhs.mediaStatus
    }
    
}
