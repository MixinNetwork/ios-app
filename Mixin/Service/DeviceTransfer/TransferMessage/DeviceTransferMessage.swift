import Foundation
import MixinServices

struct DeviceTransferMessage {
    
    let messageId: String
    let conversationId: String
    let userId: String
    let category: String
    let content: String?
    let mediaUrl: String?
    let mediaMimeType: String?
    let mediaSize: Int64?
    let mediaDuration: String?
    let mediaWidth: Int?
    let mediaHeight: Int?
    let mediaHash: String?
    let mediaKey: Data?
    let mediaDigest: Data?
    let mediaStatus: String?
    let mediaWaveform: Data?
    let thumbImage: String?
    let thumbUrl: String?
    let status: String
    let action: String?
    let participantId: String?
    let snapshotId: String?
    let name: String?
    let stickerId: String?
    let sharedUserId: String?
    let quoteMessageId: String?
    let quoteContent: String?
    let createdAt: String
    let albumId: String?
    
    init(message: Message, to platform: DeviceTransferPlatform) {
        let content: String?
        switch message.category {
        case MessageCategory.APP_CARD.rawValue:
            content = AppCardContentConverter.generalAppCard(from: message.content)
        case MessageCategory.APP_BUTTON_GROUP.rawValue:
            content = AppButtonGroupContentConverter.generalAppButtonGroup(from: message.content)
        default:
            content = message.content
        }
        
        let duration: String?
        if let mediaDuration = message.mediaDuration {
            duration = "\(mediaDuration)"
        } else {
            duration = nil
        }
        
        self.messageId = message.messageId
        self.conversationId = message.conversationId
        self.userId = message.userId
        self.category = message.category
        self.content = content
        self.mediaUrl = message.mediaUrl
        self.mediaMimeType = message.mediaMimeType
        self.mediaSize = message.mediaSize
        self.mediaDuration = duration
        self.mediaWidth = message.mediaWidth
        self.mediaHeight = message.mediaHeight
        self.mediaHash = message.mediaHash
        self.mediaKey = message.mediaKey
        self.mediaDigest = message.mediaDigest
        switch platform {
        case .iOS:
            self.mediaStatus = message.mediaStatus
        case .other:
            if message.mediaStatus == MediaStatus.PENDING.rawValue {
                self.mediaStatus = MediaStatus.CANCELED.rawValue
            } else {
                self.mediaStatus = message.mediaStatus
            }
        }
        self.mediaWaveform = message.mediaWaveform
        self.thumbImage = message.thumbImage
        self.thumbUrl = message.thumbUrl
        self.status = message.status
        self.action = message.action
        self.participantId = message.participantId
        self.snapshotId = message.snapshotId
        self.name = message.name
        self.stickerId = message.stickerId
        self.sharedUserId = message.sharedUserId
        self.quoteMessageId = message.quoteMessageId
        self.quoteContent = QuoteContentConverter.generalQuoteContent(from: message.quoteContent)
        self.createdAt = message.createdAt
        self.albumId = message.albumId
    }
    
    func toMessage() -> Message {
        let localContent: String?
        switch category {
        case MessageCategory.APP_CARD.rawValue:
            localContent = AppCardContentConverter.localAppCard(from: content)
        case MessageCategory.APP_BUTTON_GROUP.rawValue:
            localContent = AppButtonGroupContentConverter.localAppButtonGroup(from: content)
        default:
            localContent = content
        }
        
        let duration: Int64?
        if let mediaDuration {
            duration = Int64(mediaDuration)
        } else {
            duration = nil
        }
        
        return Message(messageId: messageId,
                       conversationId: conversationId,
                       userId: userId,
                       category: category,
                       content: localContent,
                       mediaUrl: mediaUrl,
                       mediaMimeType: mediaMimeType,
                       mediaSize: mediaSize,
                       mediaDuration: duration,
                       mediaWidth: mediaWidth,
                       mediaHeight: mediaHeight,
                       mediaHash: mediaHash,
                       mediaKey: mediaKey,
                       mediaDigest: mediaDigest,
                       mediaStatus: mediaStatus,
                       mediaWaveform: mediaWaveform,
                       thumbImage: thumbImage,
                       thumbUrl: thumbUrl,
                       status: MessageStatus.READ.rawValue,
                       action: action,
                       participantId: participantId,
                       snapshotId: snapshotId,
                       name: name,
                       stickerId: stickerId,
                       sharedUserId: sharedUserId,
                       quoteMessageId: quoteMessageId,
                       quoteContent: QuoteContentConverter.localQuoteContent(from: quoteContent),
                       createdAt: createdAt,
                       albumId: albumId)
    }
    
}

extension DeviceTransferMessage: DeviceTransferRecord {
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case userId = "user_id"
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
        case thumbImage = "thumb_image"
        case thumbUrl = "thumb_url"
        case status
        case action
        case participantId = "participant_id"
        case snapshotId = "snapshot_id"
        case name
        case stickerId = "sticker_id"
        case sharedUserId = "shared_user_id"
        case quoteMessageId = "quote_message_id"
        case quoteContent = "quote_content"
        case createdAt = "created_at"
        case albumId = "album_id"
    }
    
}
