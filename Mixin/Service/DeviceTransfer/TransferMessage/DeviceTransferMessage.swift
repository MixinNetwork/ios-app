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
    let mediaLocalIdentifier: String?
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
    
    init(message: Message) {
        messageId = message.messageId
        conversationId = message.conversationId
        userId = message.userId
        category = message.category
        let jsonContent: String?
        if category == MessageCategory.APP_BUTTON_GROUP.rawValue || category == MessageCategory.APP_CARD.rawValue {
            if let content = message.content, let data = Data(base64Encoded: content) {
                jsonContent = String(data: data, encoding: .utf8)
            } else {
                jsonContent = message.content
            }
        } else {
            jsonContent = message.content
        }
        content = jsonContent
        mediaUrl = message.mediaUrl
        mediaMimeType = message.mediaMimeType
        mediaSize = message.mediaSize
        mediaDuration = "\(message.mediaDuration ?? 0)"
        mediaWidth = message.mediaWidth
        mediaHeight = message.mediaHeight
        mediaHash = message.mediaHash
        mediaKey = message.mediaKey
        mediaDigest = message.mediaDigest
        mediaStatus = message.mediaStatus
        mediaWaveform = message.mediaWaveform
        mediaLocalIdentifier = message.mediaLocalIdentifier
        thumbImage = message.thumbImage
        thumbUrl = message.thumbUrl
        status = message.status
        action = message.action
        participantId = message.participantId
        snapshotId = message.snapshotId
        name = message.name
        stickerId = message.stickerId
        sharedUserId = message.sharedUserId
        quoteMessageId = message.quoteMessageId
        quoteContent = QuoteContentConverter.transcriptQuoteContent(from: message.quoteContent)
        createdAt = message.createdAt
        albumId = message.albumId
    }
    
    func toMessage() -> Message {
        Message(messageId: messageId,
                conversationId: conversationId,
                userId: userId,
                category: category,
                content: content,
                mediaUrl: mediaUrl,
                mediaMimeType: mediaMimeType,
                mediaSize: mediaSize,
                mediaDuration: Int64(mediaDuration ?? ""),
                mediaWidth: mediaWidth,
                mediaHeight: mediaHeight,
                mediaHash: mediaHash,
                mediaKey: mediaKey,
                mediaDigest: mediaDigest,
                mediaStatus: mediaStatus,
                mediaWaveform: mediaWaveform,
                mediaLocalIdentifier: mediaLocalIdentifier,
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

extension DeviceTransferMessage: Codable {
    
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
        case mediaLocalIdentifier = "media_local_id"
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
