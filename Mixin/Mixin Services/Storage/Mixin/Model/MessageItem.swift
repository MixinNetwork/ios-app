import WCDBSwift

public class MessageItem: TableCodable {
    
    public var messageId: String = ""
    public var conversationId: String = ""
    public var userId: String = ""
    public var category: String = ""
    public var content = ""
    public var mediaUrl: String? = nil
    public var mediaMimeType: String? = nil
    public var mediaSize: Int64? = nil
    public var mediaDuration: Int64? = nil
    public var mediaWidth: Int? = nil
    public var mediaHeight: Int? = nil
    public var mediaHash: String? = nil
    public var mediaKey: Data? = nil
    public var mediaDigest: Data? = nil
    public var mediaStatus: String? = nil
    public var mediaWaveform: Data? = nil
    public var mediaLocalIdentifier: String? = nil
    public var thumbImage: String? = nil
    public var thumbUrl: String? = nil
    public var status: String = ""
    public var participantId: String? = nil
    public var snapshotId: String? = nil
    public var name: String? = nil
    public var stickerId: String? = nil
    public var createdAt: String = ""
    
    public var actionName: String? = nil
    
    public var userFullName: String = ""
    public var userIdentityNumber: String = ""
    public var userAvatarUrl: String? = nil
    
    public var appId: String? = nil
    
    public var snapshotAmount: String? = nil
    public var snapshotAssetId: String? = nil
    public var snapshotType: String = ""
    
    public var participantFullName: String? = nil
    public var participantUserId: String? = nil
    
    public var assetUrl: String? = nil
    public var assetSymbol: String? = nil
    
    public var assetIcon: String? = nil
    public var assetWidth: Int? = nil
    public var assetHeight: Int? = nil
    public var assetCategory: String? = nil
    
    public var sharedUserId: String? = nil
    public var sharedUserFullName: String = ""
    public var sharedUserIdentityNumber: String = ""
    public var sharedUserAvatarUrl: String = ""
    public var sharedUserAppId: String = ""
    public var sharedUserIsVerified: Bool = false
    
    public var quoteMessageId: String? = nil
    public var quoteContent: Data? = nil
    
    public lazy var appButtons: [AppButtonData]? = {
        guard category == MessageCategory.APP_BUTTON_GROUP.rawValue, let data = Data(base64Encoded: content) else {
            return nil
        }
        return try? JSONDecoder.default.decode([AppButtonData].self, from: data)
    }()
    
    public lazy var appCard: AppCardData? = {
        guard category == MessageCategory.APP_CARD.rawValue, let data = Data(base64Encoded: content) else {
            return nil
        }
        return try? JSONDecoder.default.decode(AppCardData.self, from: data)
    }()
    
    public init() {
        
    }
    
    public convenience init(category: String, conversationId: String, createdAt: String) {
        self.init()
        self.messageId = UUID().uuidString.lowercased()
        self.status = MessageStatus.SENDING.rawValue
        self.category = category
        self.conversationId = conversationId
        self.createdAt = createdAt
    }
    
}

extension MessageItem {
    
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
    
    public var isExtensionMessage: Bool {
        return category == MessageCategory.EXT_UNREAD.rawValue || category == MessageCategory.EXT_ENCRYPTION.rawValue
    }
    
    public var isSystemMessage: Bool {
        return category == MessageCategory.SYSTEM_CONVERSATION.rawValue
    }
    
    public var userIsBot: Bool {
        return !(appId?.isEmpty ?? true)
    }
    
    public var canRecall: Bool {
        guard userId == myUserId, status != MessageStatus.SENDING.rawValue else {
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
    
    public func isRepresentativeMessage(conversation: ConversationItem) -> Bool {
        guard userId != myUserId else {
            return false
        }
        guard conversation.category != ConversationCategory.GROUP.rawValue else {
            return true
        }
        return conversation.ownerId != userId && conversation.category == ConversationCategory.CONTACT.rawValue
    }
    
}
