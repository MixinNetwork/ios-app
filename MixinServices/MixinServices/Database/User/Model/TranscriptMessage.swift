import Foundation
import GRDB

public final class TranscriptMessage {
    
    public let transcriptId: String
    public let messageId: String
    public let userId: String?
    public var userFullName: String?
    public let category: Category
    public var content: String?
    public var mediaUrl: String?
    public let mediaMimeType: String?
    public let mediaSize: Int64?
    public let mediaDuration: Int64?
    public var mediaWidth: Int?
    public var mediaHeight: Int?
    public var mediaHash: String?
    public var mediaKey: Data?
    public var mediaDigest: Data?
    public var mediaStatus: String?
    public let mediaWaveform: Data?
    public var mediaCreatedAt: String?
    public let thumbImage: String?
    public let thumbUrl: String?
    public let name: String?
    public let caption: String?
    public var stickerId: String?
    public let sharedUserId: String?
    public let quoteMessageId: String?
    public let quoteContent: String?
    public let mentions: String?
    public let createdAt: String
    
    public init?(
        transcriptId: String,
        messageItem item: MessageItem,
        content: String?,
        mediaUrl: String?,
        mediaCreatedAt: String?
    ) {
        guard let category = Category(messageCategoryString: item.category) else {
            return nil
        }
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
        self.mediaHash = item.mediaHash
        self.mediaKey = item.mediaKey
        self.mediaDigest = item.mediaDigest
        self.mediaStatus = item.mediaStatus
        self.mediaWaveform = item.mediaWaveform
        self.mediaCreatedAt = mediaCreatedAt
        self.thumbImage = item.thumbImage
        self.thumbUrl = item.thumbUrl
        self.name = item.name
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
    
    public enum Category: String, Codable {
        
        public static let attachmentIncludedCategories: Set<Category> = [.image, .video, .data, .audio]
        
        case text = "SIGNAL_TEXT"
        case image = "SIGNAL_IMAGE"
        case video = "SIGNAL_VIDEO"
        case data = "SIGNAL_DATA"
        case sticker = "SIGNAL_STICKER"
        case contact = "SIGNAL_CONTACT"
        case audio = "SIGNAL_AUDIO"
        case live = "SIGNAL_LIVE"
        case post = "SIGNAL_POST"
        case location = "SIGNAL_LOCATION"
        case appCard = "APP_CARD"
        case transcript = "SIGNAL_TRANSCRIPT"
        
        public var includesAttachment: Bool {
            Self.attachmentIncludedCategories.contains(self)
        }
        
        public init?(messageCategoryString: String) {
            guard let category = MessageCategory(rawValue: messageCategoryString) else {
                return nil
            }
            switch category {
            case .PLAIN_TEXT, .SIGNAL_TEXT:
                self = .text
            case .SIGNAL_IMAGE, .PLAIN_IMAGE:
                self = .image
            case .SIGNAL_VIDEO, .PLAIN_VIDEO:
                self = .video
            case .SIGNAL_DATA, .PLAIN_DATA:
                self = .data
            case .SIGNAL_STICKER, .PLAIN_STICKER:
                self = .sticker
            case .SIGNAL_CONTACT, .PLAIN_CONTACT:
                self = .contact
            case .SIGNAL_AUDIO, .PLAIN_AUDIO:
                self = .audio
            case .SIGNAL_LIVE, .PLAIN_LIVE:
                self = .live
            case .SIGNAL_POST, .PLAIN_POST:
                self = .post
            case .SIGNAL_LOCATION, .PLAIN_LOCATION:
                self = .location
            case .APP_CARD:
                self = .appCard
            case .SIGNAL_TRANSCRIPT:
                self = .transcript
            default:
                return nil
            }
        }
        
    }
    
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
        case content
        case mediaUrl = "media_url"
        case mediaMimeType = "media_mime_type"
        case mediaSize = "media_size"
        case mediaDuration = "media_duration"
        case mediaWidth = "media_width"
        case mediaHeight = "media_height"
        case mediaHash = "media_hash"
        case mediaKey = "media_key"
        case mediaDigest = "media_digest"
        case mediaStatus = "media_status"
        case mediaWaveform = "media_waveform"
        case mediaCreatedAt = "media_created_at"
        case thumbImage = "thumb_image"
        case thumbUrl = "thumb_url"
        case name
        case caption
        case stickerId = "sticker_id"
        case sharedUserId = "shared_user_id"
        case quoteMessageId = "quote_message_id"
        case quoteContent = "quote_content"
        case mentions
        case createdAt = "created_at"
    }
    
}

extension TranscriptMessage: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "message_transcripts"
    
}
