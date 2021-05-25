import Foundation
import GRDB

public final class TranscriptMessage {
    
    public let transcriptId: String
    public let messageId: String
    public let userId: String?
    public var userFullName: String?
    public let category: Category
    public let createdAt: String
    public var content: String?
    public var mediaUrl: String?
    public let mediaName: String?
    public let mediaSize: Int64?
    public var mediaWidth: Int?
    public var mediaHeight: Int?
    public let mediaMimeType: String?
    public let mediaDuration: Int64?
    public var mediaStatus: String?
    public let mediaWaveform: Data?
    public let thumbImage: String?
    public let thumbUrl: String?
    public var mediaKey: Data?
    public var mediaDigest: Data?
    public var mediaCreatedAt: String?
    public var stickerId: String?
    public let sharedUserId: String?
    public let mentions: String?
    public let quoteMessageId: String?
    public let quoteContent: String?
    public let caption: String?
    
    public init?(transcriptId: String, messageItem item: MessageItem, mediaUrl: String?) {
        guard let category = Category(messageCategoryString: item.category) else {
            return nil
        }
        let (content, mediaCreatedAt) = { () -> (String?, String?) in
            switch item.category {
            case MessageCategory.APP_CARD.rawValue:
                return (AppCardContentConverter.transcriptAppCard(from: item.content), nil)
            case MessageCategory.SIGNAL_VIDEO.rawValue, MessageCategory.PLAIN_VIDEO.rawValue:
                if let data = item.content?.data(using: .utf8), let tad = try? JSONDecoder.default.decode(TransferAttachmentData.self, from: data) {
                    return (tad.attachmentId, tad.createdAt)
                } else {
                    return (nil, nil)
                }
            default:
                return (item.content, nil)
            }
        }()
        self.transcriptId = transcriptId
        self.messageId = item.messageId
        self.userId = item.userId
        self.userFullName = item.userFullName
        self.category = category
        self.content = content
        self.mediaUrl = mediaUrl ?? item.assetUrl
        self.mediaMimeType = item.mediaMimeType
        self.mediaSize = item.mediaSize
        self.mediaDuration = item.mediaDuration
        self.mediaWidth = item.mediaWidth ?? item.assetWidth
        self.mediaHeight = item.mediaHeight ?? item.assetHeight
        self.mediaKey = item.mediaKey
        self.mediaDigest = item.mediaDigest
        self.mediaStatus = item.mediaStatus
        self.mediaWaveform = item.mediaWaveform
        self.mediaCreatedAt = mediaCreatedAt
        self.thumbImage = item.thumbImage
        self.thumbUrl = item.thumbUrl
        self.mediaName = item.name
        self.caption = nil
        self.stickerId = item.stickerId
        self.sharedUserId = item.sharedUserId
        self.quoteMessageId = item.quoteMessageId
        self.quoteContent = QuoteContentConverter.transcriptQuoteContent(from: item.quoteContent)
        self.mentions = MentionConverter.transcriptMention(from: item.mentionsJson)
        self.createdAt = item.createdAt
    }
    
}

extension TranscriptMessage {
    
    public struct LocalContent: Codable {
        public let name: String?
        public let category: Category
        public let content: String?
    }
    
}

extension TranscriptMessage: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case transcriptId = "transcript_id"
        case messageId = "message_id"
        case userId = "user_id"
        case userFullName = "user_full_name"
        case category
        case createdAt = "created_at"
        case content
        case mediaUrl = "media_url"
        case mediaName = "media_name"
        case mediaSize = "media_size"
        case mediaWidth = "media_width"
        case mediaHeight = "media_height"
        case mediaMimeType = "media_mime_type"
        case mediaDuration = "media_duration"
        case mediaStatus = "media_status"
        case mediaWaveform = "media_waveform"
        case thumbImage = "thumb_image"
        case thumbUrl = "thumb_url"
        case mediaKey = "media_key"
        case mediaDigest = "media_digest"
        case mediaCreatedAt = "media_created_at"
        case stickerId = "sticker_id"
        case sharedUserId = "shared_user_id"
        case mentions
        case quoteMessageId = "quote_id"
        case quoteContent = "quote_content"
        case caption
    }
    
}

extension TranscriptMessage: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "transcript_messages"
    
}
