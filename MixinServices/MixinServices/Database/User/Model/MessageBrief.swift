import Foundation

public class MessageBrief: Codable {
    
    public let messageId: String
    public let userId: String?
    public let userFullName: String?
    public let category: Category
    public let createdAt: String
    public var content: String?
    public var mediaUrl: String?
    public let mediaName: String?
    public let mediaMimeType: String?
    public let mediaSize: Int64?
    public var mediaWidth: Int?
    public var mediaHeight: Int?
    public let mediaDuration: Int64?
    public var mediaStatus: String?
    public let mediaWaveform: Data?
    public var mediaKey: Data?
    public var mediaDigest: Data?
    public var attachmentCreatedAt: String?
    public let thumbImage: String?
    public let thumbUrl: String?
    public var stickerId: String?
    public let sharedUserId: String?
    public let sharedUserFullName: String?
    public let sharedUserIdentityNumber: String?
    public let sharedUserAvatarUrl: String?
    public let sharedUserAppId: String?
    public let sharedUserIsVerified: Bool?
    public let mentions: String?
    public let quoteId: String?
    public let quoteContent: String?
    
    public init?(messageItem item: MessageItem, mediaUrl: String?) {
        guard let category = Category(messageCategoryString: item.category) else {
            return nil
        }
        self.messageId = item.messageId
        self.userId = item.userId
        self.userFullName = item.userFullName
        self.category = category
        self.createdAt = item.createdAt
        if category == .appCard {
            self.content = AppCardContentConverter.transcriptAppCard(from: item.content)
        } else {
            self.content = item.content
        }
        self.mediaUrl = mediaUrl ?? item.assetUrl
        self.mediaName = item.name
        self.mediaMimeType = item.mediaMimeType
        self.mediaSize = item.mediaSize
        self.mediaWidth = item.mediaWidth ?? item.assetWidth
        self.mediaHeight = item.mediaHeight ?? item.assetHeight
        self.mediaDuration = item.mediaDuration
        self.mediaStatus = item.mediaStatus
        self.mediaWaveform = item.mediaWaveform
        self.mediaKey = item.mediaKey
        self.mediaDigest = item.mediaDigest
        self.attachmentCreatedAt = nil
        self.thumbImage = item.thumbImage
        self.thumbUrl = item.thumbUrl
        self.stickerId = item.stickerId
        self.sharedUserId = item.sharedUserId
        self.sharedUserFullName = item.sharedUserFullName
        self.sharedUserIdentityNumber = item.sharedUserIdentityNumber
        self.sharedUserAvatarUrl = item.sharedUserAvatarUrl
        self.sharedUserAppId = item.sharedUserAppId
        self.sharedUserIsVerified = item.sharedUserIsVerified
        self.mentions = MentionConverter.transcriptMention(from: item.mentionsJson)
        self.quoteId = item.quoteMessageId
        self.quoteContent = QuoteContentConverter.transcriptQuoteContent(from: item.quoteContent)
    }
    
}

extension MessageBrief {
    
    public enum Category: String, Codable {
        
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
        
        public var includesAttachment: Bool {
            [.image, .video, .data, .audio].contains(self)
        }
        
    }
    
}
