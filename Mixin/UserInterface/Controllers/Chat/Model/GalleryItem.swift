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
    
    init?(messageId: String, category: String, mediaUrl: String?, mediaMimeType: String?, mediaWidth: Int?, mediaHeight: Int?, mediaStatus: String?, thumbImage: String?, createdAt: String) {
        if GalleryItem.imageCategories.contains(category) {
            self.category = .image
            if let mediaUrl = mediaUrl {
                self.url = MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl)
            } else {
                self.url = nil
            }
        } else if GalleryItem.videoCategories.contains(category) {
            self.category = .video
            if let mediaUrl = mediaUrl {
                self.url = MixinFile.url(ofChatDirectory: .videos, filename: mediaUrl)
            } else {
                self.url = nil
            }
        } else {
            return nil
        }
        self.mediaMimeType = mediaMimeType
        self.messageId = messageId
        let width = max(1, mediaWidth ?? 1)
        let height = max(1, mediaHeight ?? 1)
        self.size = CGSize(width: width, height: height)
        if let thumbImage = thumbImage, let data = Data(base64Encoded: thumbImage) {
            self.thumbnail = UIImage(data: data)
        } else {
            self.thumbnail = nil
        }
        self.createdAt = createdAt
        self.shouldLayoutAsArticle = GalleryItem.shouldLayoutImageOfRatioAsAriticle(size)
        self.mediaStatus = MediaStatus(rawValue: mediaStatus ?? "")
    }
    
    init?(message m: GalleryItemRepresentable) {
        self.init(messageId: m.messageId,
                  category: m.category,
                  mediaUrl: m.mediaUrl,
                  mediaMimeType: m.mediaMimeType,
                  mediaWidth: m.mediaWidth,
                  mediaHeight: m.mediaHeight,
                  mediaStatus: m.mediaStatus,
                  thumbImage: m.thumbImage,
                  createdAt: m.createdAt)
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
