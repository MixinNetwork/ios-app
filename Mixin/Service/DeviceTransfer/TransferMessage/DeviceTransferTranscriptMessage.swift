import Foundation
import MixinServices

struct DeviceTransferTranscriptMessage {
    
    let transcriptId: String
    let messageId: String
    let userId: String?
    let userFullName: String?
    let category: String
    let createdAt: String
    let content: String?
    let mediaUrl: String?
    let mediaName: String?
    let mediaSize: Int64?
    let mediaWidth: Int?
    let mediaHeight: Int?
    let mediaMimeType: String?
    let mediaDuration: Int64?
    let mediaStatus: String?
    let mediaWaveform: Data?
    let thumbImage: String?
    let thumbUrl: String?
    let mediaKey: Data?
    let mediaDigest: Data?
    let mediaCreatedAt: String?
    let stickerId: String?
    let sharedUserId: String?
    let mentions: String?
    let quoteMessageId: String?
    let quoteContent: String?
    let caption: String?
    
    init(transcriptMessage: TranscriptMessage, to platform: DeviceTransferPlatform) {
        transcriptId = transcriptMessage.transcriptId
        messageId = transcriptMessage.messageId
        userId = transcriptMessage.userId
        userFullName = transcriptMessage.userFullName
        category = transcriptMessage.category
        createdAt = transcriptMessage.createdAt
        content = transcriptMessage.content
        mediaUrl = transcriptMessage.mediaUrl
        mediaName = transcriptMessage.mediaName
        mediaSize = transcriptMessage.mediaSize
        mediaWidth = transcriptMessage.mediaWidth
        mediaHeight = transcriptMessage.mediaHeight
        mediaMimeType = transcriptMessage.mediaMimeType
        mediaDuration = transcriptMessage.mediaDuration
        switch platform {
        case .iOS:
            mediaStatus = transcriptMessage.mediaStatus
        case .other:
            mediaStatus = transcriptMessage.mediaStatus == MediaStatus.PENDING.rawValue ? MediaStatus.CANCELED.rawValue : transcriptMessage.mediaStatus
        }
        mediaWaveform = transcriptMessage.mediaWaveform
        thumbImage = transcriptMessage.thumbImage
        thumbUrl = transcriptMessage.thumbUrl
        mediaKey = transcriptMessage.mediaKey
        mediaDigest = transcriptMessage.mediaDigest
        mediaCreatedAt = transcriptMessage.mediaCreatedAt
        stickerId = transcriptMessage.stickerId
        sharedUserId = transcriptMessage.sharedUserId
        mentions = transcriptMessage.mentions
        quoteMessageId = transcriptMessage.quoteMessageId
        quoteContent = transcriptMessage.quoteContent
        caption = transcriptMessage.caption
    }
    
    func toTranscriptMessage() -> TranscriptMessage {
        TranscriptMessage(transcriptId: transcriptId,
                          messageId: messageId,
                          userId: userId,
                          userFullName: userFullName,
                          category: category,
                          createdAt: createdAt,
                          content: content,
                          mediaUrl: mediaUrl,
                          mediaName: mediaName,
                          mediaSize: mediaSize,
                          mediaWidth: mediaWidth,
                          mediaHeight: mediaHeight,
                          mediaMimeType: mediaMimeType,
                          mediaDuration:mediaDuration,
                          mediaStatus: mediaStatus,
                          mediaWaveform: mediaWaveform,
                          thumbImage: thumbImage,
                          thumbUrl: thumbUrl,
                          mediaKey: mediaKey,
                          mediaDigest: mediaDigest,
                          mediaCreatedAt: mediaCreatedAt,
                          stickerId: stickerId,
                          sharedUserId: sharedUserId,
                          mentions: mentions,
                          quoteMessageId: quoteMessageId,
                          quoteContent: quoteContent,
                          caption: caption)
    }
}

extension DeviceTransferTranscriptMessage: DeviceTransferRecord {
    
    enum CodingKeys: String, CodingKey {
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
