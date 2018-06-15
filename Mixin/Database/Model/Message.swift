import Foundation
import WCDBSwift

struct Message: BaseCodable {

    static var tableName: String = "messages"

    var messageId: String
    var conversationId: String
    var userId: String
    var category: String
    var content: String? = nil
    var mediaUrl: String? = nil
    var mediaMimeType: String? = nil
    var mediaSize: Int64? = nil
    var mediaDuration: Int64? = nil
    var mediaWidth: Int? = nil
    var mediaHeight: Int? = nil
    var mediaHash: String? = nil
    var mediaKey: Data? = nil
    var mediaDigest: Data? = nil
    var mediaStatus: String? = nil
    var thumbImage: String? = nil
    var status: String
    var action: String? = nil
    var participantId: String? = nil
    var snapshotId: String? = nil
    var name: String? = nil
    var albumId: String? = nil
    var stickerId: String? = nil
    var sharedUserId: String? = nil
    var createdAt: String

    enum CodingKeys: String, CodingTableKey {
        typealias Root = Message
        case messageId = "id"
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
        case thumbImage = "thumb_image"
        case status
        case action
        case participantId = "participant_id"
        case snapshotId = "snapshot_id"
        case name
        case albumId = "album_id"
        case stickerId = "sticker_id"
        case sharedUserId = "shared_user_id"
        case createdAt = "created_at"

        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                messageId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_index1": IndexBinding(indexesBy: [conversationId]),
                "_index2": IndexBinding(indexesBy: [createdAt])
            ]
        }
        static var tableConstraintBindings: [TableConstraintBinding.Name: TableConstraintBinding]? {
            let foreignKey = ForeignKey(withForeignTable: Conversation.tableName, and: conversationId).onDelete(.cascade)
            return [
                "_foreign_key_constraint": ForeignKeyBinding(conversationId, foreignKey: foreignKey)
            ]
        }
    }
}

extension Message {

    static func createMessage(snapshotMesssage snapshot: Snapshot, data: BlazeMessageData) -> Message {
        return Message(messageId: data.messageId, conversationId: data.conversationId, userId: data.userId, category: data.category, content: nil, mediaUrl: nil, mediaMimeType: nil, mediaSize: nil, mediaDuration: nil, mediaWidth: nil, mediaHeight: nil, mediaHash: nil, mediaKey: nil, mediaDigest: nil, mediaStatus: nil, thumbImage: nil, status: MessageStatus.DELIVERED.rawValue, action: snapshot.type, participantId: nil, snapshotId: snapshot.snapshotId, name: nil, albumId: nil, stickerId: nil, sharedUserId: nil, createdAt: data.createdAt)
    }

    static func createMessage(textMessage plainText: String, data: BlazeMessageData) -> Message {
        return Message(messageId: data.messageId, conversationId: data.conversationId, userId: data.getSenderId(), category: data.category, content: plainText, mediaUrl: nil, mediaMimeType: nil, mediaSize: nil, mediaDuration: nil, mediaWidth: nil, mediaHeight: nil, mediaHash: nil, mediaKey: nil, mediaDigest: nil, mediaStatus: nil, thumbImage: nil, status: MessageStatus.DELIVERED.rawValue, action: nil, participantId: nil, snapshotId: nil, name: nil, albumId: nil, stickerId: nil, sharedUserId: nil, createdAt: data.createdAt)
    }

    static func createMessage(systemMessage action: String?, participantId: String?, userId: String, data: BlazeMessageData) -> Message {
        return Message(messageId: data.messageId, conversationId: data.conversationId, userId: userId, category: data.category, content: nil, mediaUrl: nil, mediaMimeType: nil, mediaSize: nil, mediaDuration: nil, mediaWidth: nil, mediaHeight: nil, mediaHash: nil, mediaKey: nil, mediaDigest: nil, mediaStatus: nil, thumbImage: nil, status: MessageStatus.READ.rawValue, action: action, participantId: participantId, snapshotId: nil, name: nil, albumId: nil, stickerId: nil, sharedUserId: nil, createdAt: data.createdAt)
    }

    static func createMessage(appMessage data: BlazeMessageData) -> Message {
        return Message(messageId: data.messageId, conversationId: data.conversationId, userId: data.getSenderId(), category: data.category, content: data.data, mediaUrl: nil, mediaMimeType: nil, mediaSize: nil, mediaDuration: nil, mediaWidth: nil, mediaHeight: nil, mediaHash: nil, mediaKey: nil, mediaDigest: nil, mediaStatus: nil, thumbImage: nil, status: MessageStatus.DELIVERED.rawValue, action: nil, participantId: nil, snapshotId: nil, name: nil, albumId: nil, stickerId: nil, sharedUserId: nil, createdAt: data.createdAt)
    }

    static func createMessage(stickerData: TransferStickerData, data: BlazeMessageData) -> Message {
        return Message(messageId: data.messageId, conversationId: data.conversationId, userId: data.getSenderId(), category: data.category, content: nil, mediaUrl: nil, mediaMimeType: nil, mediaSize: nil, mediaDuration: nil, mediaWidth: nil, mediaHeight: nil, mediaHash: nil, mediaKey: nil, mediaDigest: nil, mediaStatus: nil, thumbImage: nil, status: MessageStatus.DELIVERED.rawValue, action: nil, participantId: nil, snapshotId: nil, name: stickerData.name, albumId: stickerData.albumId, stickerId: stickerData.stickerId, sharedUserId: nil, createdAt: data.createdAt)
    }

    static func createMessage(contactData: TransferContactData, data: BlazeMessageData) -> Message {
        return Message(messageId: data.messageId, conversationId: data.conversationId, userId: data.getSenderId(), category: data.category, content: nil, mediaUrl: nil, mediaMimeType: nil, mediaSize: nil, mediaDuration: nil, mediaWidth: nil, mediaHeight: nil, mediaHash: nil, mediaKey: nil, mediaDigest: nil, mediaStatus: nil, thumbImage: nil, status: MessageStatus.DELIVERED.rawValue, action: nil, participantId: nil, snapshotId: nil, name: nil, albumId: nil, stickerId: nil, sharedUserId: contactData.userId, createdAt: data.createdAt)
    }

    static func createMessage(mediaData: TransferAttachmentData, data: BlazeMessageData) -> Message {
        let mediaStatus = data.category.hasSuffix("_DATA") || data.category.hasSuffix("_VIDEO") ? MediaStatus.CANCELED.rawValue : MediaStatus.PENDING.rawValue
        return Message(messageId: data.messageId, conversationId: data.conversationId, userId: data.getSenderId(), category: data.category, content: mediaData.attachmentId, mediaUrl: nil, mediaMimeType: mediaData.mimeType, mediaSize: mediaData.size, mediaDuration: mediaData.duration, mediaWidth: mediaData.width, mediaHeight: mediaData.height, mediaHash: nil, mediaKey: mediaData.key, mediaDigest: mediaData.digest, mediaStatus: mediaStatus, thumbImage: mediaData.thumbnail, status: MessageStatus.DELIVERED.rawValue, action: nil, participantId: nil, snapshotId: nil, name: mediaData.name, albumId: nil, stickerId: nil, sharedUserId: nil, createdAt: data.createdAt)
    }

    static func createMessage(messageId: String = UUID().uuidString.lowercased(), category: String, conversationId: String, createdAt: String = Date().toUTCString(), userId: String) -> Message {
        return Message(messageId: messageId, conversationId: conversationId, userId: userId, category: category, content: nil, mediaUrl: nil, mediaMimeType: nil, mediaSize: nil, mediaDuration: nil, mediaWidth: nil, mediaHeight: nil, mediaHash: nil, mediaKey: nil, mediaDigest: nil, mediaStatus: nil, thumbImage: nil, status: MessageStatus.SENDING.rawValue, action: nil, participantId: nil, snapshotId: nil, name: nil, albumId: nil, stickerId: nil, sharedUserId: nil, createdAt: createdAt)
    }

    static func createMessage(message: MessageItem) -> Message {
        return Message(messageId: message.messageId, conversationId: message.conversationId, userId: message.userId, category: message.category, content: message.content, mediaUrl: message.mediaUrl, mediaMimeType: message.mediaMimeType, mediaSize: message.mediaSize, mediaDuration: message.mediaDuration, mediaWidth: message.mediaWidth, mediaHeight: message.mediaHeight, mediaHash: message.mediaHash, mediaKey: message.mediaKey, mediaDigest: message.mediaDigest, mediaStatus: message.mediaStatus, thumbImage: message.thumbImage, status: message.status, action: message.actionName, participantId: message.participantId, snapshotId: message.snapshotId, name: message.name, albumId: message.albumId, stickerId: message.stickerId, sharedUserId: nil, createdAt: message.createdAt)
    }

}

enum MessageCategory: String {
    case SIGNAL_KEY
    case SIGNAL_TEXT
    case SIGNAL_IMAGE
    case SIGNAL_VIDEO
    case SIGNAL_DATA
    case SIGNAL_STICKER
    case SIGNAL_CONTACT
    case PLAIN_TEXT
    case PLAIN_IMAGE
    case PLAIN_VIDEO
    case PLAIN_DATA
    case PLAIN_STICKER
    case PLAIN_CONTACT
    case PLAIN_JSON
    case APP_CARD
    case APP_BUTTON_GROUP
    case SYSTEM_CONVERSATION
    case SYSTEM_ACCOUNT_SNAPSHOT
    case EXT_UNREAD
    case EXT_ENCRYPTION
    case UNKNOWN
}

enum MessageStatus: String, Codable {
    case SENDING
    case SENT
    case DELIVERED
    case READ
    case UNKNOWN
    case FAILED

    static func getOrder(messageStatus: String) -> Int {
        switch messageStatus {
        case MessageStatus.SENDING.rawValue:
            return 0
        case MessageStatus.SENT.rawValue:
            return 1
        case MessageStatus.FAILED.rawValue:
            return 2
        case MessageStatus.DELIVERED.rawValue:
            return 3
        case MessageStatus.READ.rawValue:
            return 4
        default:
            return -1
        }
    }
}

enum MediaStatus: String {
    case PENDING
    case DONE
    case CANCELED
    case EXPIRED
}
