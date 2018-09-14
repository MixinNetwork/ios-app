import UIKit

protocol GalleryItemRepresentable {
    var messageId: String { get }
    var category: String { get }
    var mediaUrl: String? { get }
    var mediaMimeType: String? { get }
    var mediaWidth: Int? { get }
    var mediaHeight: Int? { get }
    var mediaStatus: String? { get }
    var thumbImage: String? { get }
    var createdAt: String { get }
}

extension Message: GalleryItemRepresentable { }
extension MessageItem: GalleryItemRepresentable { }

struct GalleryItem: Equatable {
    
    enum Category {
        case image
        case video
    }
    
    private static let imageCategories: [String] = [
        MessageCategory.SIGNAL_IMAGE.rawValue,
        MessageCategory.PLAIN_IMAGE.rawValue
    ]
    
    private static let videoCategories: [String] = [
        MessageCategory.SIGNAL_VIDEO.rawValue,
        MessageCategory.PLAIN_VIDEO.rawValue
    ]
    
    let category: Category
    let messageId: String
    let url: URL?
    let size: CGSize
    let thumbnail: UIImage?
    let mediaMimeType: String?
    let createdAt: String
    let shouldLayoutAsArticle: Bool
    var mediaStatus: MediaStatus?
    
    init?(message: GalleryItemRepresentable) {
        if GalleryItem.imageCategories.contains(message.category) {
            category = .image
            if let mediaUrl = message.mediaUrl {
                url = MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl)
            } else {
                url = nil
            }
        } else if GalleryItem.videoCategories.contains(message.category) {
            category = .video
            if let mediaUrl = message.mediaUrl {
                url = MixinFile.url(ofChatDirectory: .videos, filename: mediaUrl)
            } else {
                url = nil
            }
        } else {
            return nil
        }
        mediaMimeType = message.mediaMimeType
        messageId = message.messageId
        let width = max(1, message.mediaWidth ?? 1)
        let height = max(1, message.mediaHeight ?? 1)
        size = CGSize(width: width, height: height)
        if let thumbImage = message.thumbImage, let data = Data(base64Encoded: thumbImage) {
            thumbnail = UIImage(data: data)
        } else {
            thumbnail = nil
        }
        createdAt = message.createdAt
        shouldLayoutAsArticle = GalleryItem.shouldLayoutImageOfRatioAsAriticle(size)
        mediaStatus = MediaStatus(rawValue: message.mediaStatus ?? "")
    }
    
    static func ==(lhs: GalleryItem, rhs: GalleryItem) -> Bool {
        return lhs.messageId == rhs.messageId
            && lhs.url == rhs.url
            && lhs.mediaStatus == rhs.mediaStatus
    }
    
    static func shouldLayoutImageOfRatioAsAriticle(_ ratio: CGSize) -> Bool {
        return ratio.height / ratio.width > 3
    }
    
}
