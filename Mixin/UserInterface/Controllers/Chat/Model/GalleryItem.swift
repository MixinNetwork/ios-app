import UIKit
import MixinServices

protocol GalleryItemRepresentable {
    var conversationId: String { get }
    var messageId: String { get }
    var category: String { get }
    var mediaUrl: String? { get }
    var mediaMimeType: String? { get }
    var mediaWidth: Int? { get }
    var mediaHeight: Int? { get }
    var mediaStatus: String? { get }
    var mediaDuration: Int64? { get }
    var thumbImage: String? { get }
    var thumbUrl: String? { get }
    var createdAt: String { get }
}

extension Message: GalleryItemRepresentable { }
extension MessageItem: GalleryItemRepresentable { }

struct GalleryItem: Equatable {
    
    enum Category {
        case image
        case video
        case live
    }
    
    enum Thumbnail {
        case url(URL)
        case image(UIImage)
        case none
    }
    
    private static let imageCategories: [String] = [
        MessageCategory.SIGNAL_IMAGE.rawValue,
        MessageCategory.PLAIN_IMAGE.rawValue
    ]
    private static let videoCategories: [String] = [
        MessageCategory.SIGNAL_VIDEO.rawValue,
        MessageCategory.PLAIN_VIDEO.rawValue
    ]
    private static let streamCategories: [String] = [
        MessageCategory.SIGNAL_LIVE.rawValue,
        MessageCategory.PLAIN_LIVE.rawValue
    ]
    
    let transcriptId: String?
    let category: Category
    let conversationId: String
    let messageId: String
    let url: URL?
    let size: CGSize
    let thumbnail: Thumbnail
    let mediaMimeType: String?
    let mediaDuration: Int64
    let createdAt: String
    let shouldLayoutAsArticle: Bool
    var mediaStatus: MediaStatus?
    
    init?(
        transcriptId: String?,
        conversationId: String,
        messageId: String,
        category: String,
        mediaUrl: String?,
        mediaMimeType: String?,
        mediaWidth: Int?,
        mediaHeight: Int?,
        mediaStatus: String?,
        mediaDuration: Int64?,
        thumbImage: String?,
        thumbUrl: String?,
        createdAt: String
    ) {
        self.transcriptId = transcriptId
        self.conversationId = conversationId
        if GalleryItem.imageCategories.contains(category) {
            self.category = .image
            if let mediaUrl = mediaUrl {
                if let tid = transcriptId {
                    self.url = AttachmentContainer.url(transcriptId: tid, filename: mediaUrl)
                } else {
                    self.url = AttachmentContainer.url(for: .photos, filename: mediaUrl)
                }
            } else {
                self.url = nil
            }
        } else if GalleryItem.videoCategories.contains(category) {
            self.category = .video
            if let mediaUrl = mediaUrl {
                if let tid = transcriptId {
                    self.url = AttachmentContainer.url(transcriptId: tid, filename: mediaUrl)
                } else {
                    self.url = AttachmentContainer.url(for: .videos, filename: mediaUrl)
                }
            } else {
                self.url = nil
            }
        } else if GalleryItem.streamCategories.contains(category) {
            if let mediaUrl = mediaUrl, let url = URL(string: mediaUrl) {
                self.url = url
            } else {
                return nil
            }
            self.category = .live
        } else {
            return nil
        }
        self.mediaMimeType = mediaMimeType
        self.messageId = messageId
        let width = max(1, mediaWidth ?? 1)
        let height = max(1, mediaHeight ?? 1)
        self.size = CGSize(width: width, height: height)
        if let thumbUrl = thumbUrl, let url = URL(string: thumbUrl) {
            self.thumbnail = .url(url)
        } else if self.category == .video, let videoFilename = mediaUrl {
            let coverUrl: URL
            if let tid = transcriptId {
                coverUrl = AttachmentContainer.videoThumbnailURL(transcriptId: tid, videoFilename: videoFilename)
            } else {
                coverUrl = AttachmentContainer.videoThumbnailURL(videoFilename: videoFilename)
            }
            self.thumbnail = .url(coverUrl)
        } else if let image = UIImage(thumbnailString: thumbImage) {
            self.thumbnail = .image(image)
        } else {
            self.thumbnail = .none
        }
        self.createdAt = createdAt
        self.shouldLayoutAsArticle = imageWithRatioMaybeAnArticle(size)
        self.mediaStatus = MediaStatus(rawValue: mediaStatus ?? "")
        self.mediaDuration = mediaDuration ?? 0
    }
    
    init?(transcriptId: String? = nil, message m: GalleryItemRepresentable) {
        self.init(transcriptId: transcriptId,
                  conversationId: m.conversationId,
                  messageId: m.messageId,
                  category: m.category,
                  mediaUrl: m.mediaUrl,
                  mediaMimeType: m.mediaMimeType,
                  mediaWidth: m.mediaWidth,
                  mediaHeight: m.mediaHeight,
                  mediaStatus: m.mediaStatus,
                  mediaDuration: m.mediaDuration,
                  thumbImage: m.thumbImage,
                  thumbUrl: m.thumbUrl,
                  createdAt: m.createdAt)
    }
    
    init?(viewModel v: MessageViewModel) {
        self.init(transcriptId: (v as? AttachmentLoadingViewModel)?.transcriptId,
                  conversationId: v.message.conversationId,
                  messageId: v.message.messageId,
                  category: v.message.category,
                  mediaUrl: v.message.mediaUrl,
                  mediaMimeType: v.message.mediaMimeType,
                  mediaWidth: v.message.mediaWidth,
                  mediaHeight: v.message.mediaHeight,
                  mediaStatus: v.message.mediaStatus,
                  mediaDuration: v.message.mediaDuration,
                  thumbImage: v.message.thumbImage,
                  thumbUrl: v.message.thumbUrl,
                  createdAt: v.message.createdAt)
    }
    
    static func ==(lhs: GalleryItem, rhs: GalleryItem) -> Bool {
        return lhs.messageId == rhs.messageId
    }
    
}
