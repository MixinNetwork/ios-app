import WCDBSwift

public class MessageItem: TableCodable {
    
    static let jsonDecoder = JSONDecoder()
    
    var messageId: String = ""
    var conversationId: String = ""
    var userId: String = ""
    var category: String = ""
    var content = ""
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
    var mediaWaveform: Data? = nil
    var mediaLocalIdentifier: String? = nil
    var thumbImage: String? = nil
    var thumbUrl: String? = nil
    var status: String = ""
    var participantId: String? = nil
    var snapshotId: String? = nil
    var name: String? = nil
    var stickerId: String? = nil
    var createdAt: String = ""
    
    var actionName: String? = nil
    
    var userFullName: String = ""
    var userIdentityNumber: String = ""
    var userAvatarUrl: String? = nil
    
    var appId: String? = nil
    
    var snapshotAmount: String? = nil
    var snapshotAssetId: String? = nil
    var snapshotType: String = ""
    
    var participantFullName: String? = nil
    var participantUserId: String? = nil
    
    var assetUrl: String? = nil
    var assetSymbol: String? = nil
    
    var assetIcon: String? = nil
    var assetWidth: Int? = nil
    var assetHeight: Int? = nil
    var assetCategory: String? = nil
    
    var sharedUserId: String? = nil
    var sharedUserFullName: String = ""
    var sharedUserIdentityNumber: String = ""
    var sharedUserAvatarUrl: String = ""
    var sharedUserAppId: String = ""
    var sharedUserIsVerified: Bool = false
    
    var quoteMessageId: String? = nil
    var quoteContent: Data? = nil
    
    var userIsBot: Bool {
        return !(appId?.isEmpty ?? true)
    }
    
    lazy var appButtons: [AppButtonData]? = {
        guard category == MessageCategory.APP_BUTTON_GROUP.rawValue, let data = Data(base64Encoded: content) else {
            return nil
        }
        return try? MessageItem.jsonDecoder.decode([AppButtonData].self, from: data)
    }()
    
    lazy var appCard: AppCardData? = {
        guard category == MessageCategory.APP_CARD.rawValue, let data = Data(base64Encoded: content) else {
            return nil
        }
        return try? MessageItem.jsonDecoder.decode(AppCardData.self, from: data)
    }()
    
    lazy var quoteSubtitle: String = {
        if category.hasSuffix("_TEXT") {
            return content
        } else if category.hasSuffix("_STICKER") {
            return Localized.CHAT_QUOTE_TYPE_STICKER
        } else if category.hasSuffix("_IMAGE") {
            return Localized.CHAT_QUOTE_TYPE_PHOTO
        } else if category.hasSuffix("_VIDEO") {
            return Localized.CHAT_QUOTE_TYPE_VIDEO
        } else if category.hasSuffix("_LIVE") {
            return R.string.localizable.chat_quote_type_live()
        } else if category.hasSuffix("_AUDIO") {
            if let duration = mediaDuration {
                return mediaDurationFormatter.string(from: TimeInterval(Double(duration) / millisecondsPerSecond)) ?? ""
            } else {
                return ""
            }
        } else if category.hasSuffix("_DATA") {
            return name ?? ""
        } else if category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
            return (snapshotAmount ?? "0") + " " + (assetSymbol ?? "")
        } else if category.hasSuffix("_CONTACT") {
            return sharedUserIdentityNumber
        } else if category == MessageCategory.APP_CARD.rawValue {
            return appCard?.description ?? ""
        } else if category == MessageCategory.APP_BUTTON_GROUP.rawValue {
            return appButtons?.first?.label ?? ""
        } else {
            return ""
        }
    }()
    
    var isExtensionMessage: Bool {
        return category == MessageCategory.EXT_UNREAD.rawValue || category == MessageCategory.EXT_ENCRYPTION.rawValue
    }
    
    var isSystemMessage: Bool {
        return category == MessageCategory.SYSTEM_CONVERSATION.rawValue
    }
    
    init() {
        
    }
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = MessageItem
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
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
        case mediaWaveform = "media_waveform"
        case mediaLocalIdentifier = "media_local_id"
        case thumbImage = "thumb_image"
        case thumbUrl = "thumb_url"
        case status
        case participantId = "participant_id"
        case snapshotId = "snapshot_id"
        case name
        case stickerId = "sticker_id"
        case createdAt = "created_at"
        
        case userFullName
        case userIdentityNumber
        case userAvatarUrl
        
        case appId
        
        case participantFullName
        case participantUserId
        
        case snapshotAmount
        case snapshotAssetId
        case snapshotType
        
        case assetSymbol
        case assetIcon
        
        case assetWidth
        case assetHeight
        case assetUrl
        case assetCategory
        
        case actionName
        
        case sharedUserId
        case sharedUserFullName
        case sharedUserIdentityNumber
        case sharedUserAvatarUrl
        case sharedUserAppId
        case sharedUserIsVerified
        
        case quoteMessageId = "quote_message_id"
        case quoteContent = "quote_content"
        
    }
    
}

extension MessageItem {
    
    static func createMessage(category: String, conversationId: String, createdAt: String) -> MessageItem {
        let message = MessageItem()
        message.messageId = UUID().uuidString.lowercased()
        message.status = MessageStatus.SENDING.rawValue
        message.category = category
        message.conversationId = conversationId
        message.createdAt = createdAt
        return message
    }
    
}

extension MessageItem {
    
    func isRepresentativeMessage(conversation: ConversationItem) -> Bool {
        guard userId != AccountAPI.shared.accountUserId else {
            return false
        }
        guard conversation.category != ConversationCategory.GROUP.rawValue else {
            return true
        }
        return conversation.ownerId != userId && conversation.category == ConversationCategory.CONTACT.rawValue
    }
    
    func canRecall() -> Bool {
        guard userId == AccountAPI.shared.accountUserId, status != MessageStatus.SENDING.rawValue else {
            return false
        }
        guard SendMessageService.recallableSuffices.contains(where: category.hasSuffix) else {
            return false
        }
        guard abs(createdAt.toUTCDate().timeIntervalSinceNow) < 3600 else {
            return false
        }
        
        return true
    }
    
}
