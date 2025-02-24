import Foundation
import GRDB

public final class ConversationItem {
    
    public var conversationId: String = ""
    public var ownerId: String = ""
    public var category: String?
    public var name: String = ""
    public var iconUrl: String = ""
    public var announcement: String = ""
    public var lastReadMessageId: String?
    public var unseenMessageCount: Int = 0
    public var unseenMentionCount: Int = 0
    public var status: Int = ConversationStatus.START.rawValue
    public var muteUntil: String?
    public var codeUrl: String?
    public var pinTime: String?
    public var createdAt: String = ""
    public var expireIn: Int64 = 0
    
    public var ownerIdentityNumber: String = ""
    public var ownerFullName: String = ""
    public var ownerAvatarUrl: String = ""
    public var ownerIsVerified = false
    public var ownerMembership: User.Membership?
    
    public var messageStatus: String = ""
    public var messageId: String = ""
    public var content: String?
    public var contentType: String = ""
    public var contentExpireIn: Int64 = 0
    
    public var senderId: String = ""
    public var senderFullName: String = ""
    
    public var participantFullName: String?
    public var participantUserId: String?
    
    public var appId: String?
    public var actionName: String?
    
    public var mentionsJson: Data?
    
    public lazy var appButtons: [AppButtonData]? = {
        guard let content = content else {
            return nil
        }
        let appButtonData: Data
        if let data = Data(base64Encoded: content) {
            appButtonData = data
        } else if let data = content.data(using: .utf8) {
            appButtonData = data
        } else {
            return nil
        }
        return try? JSONDecoder().decode([AppButtonData].self, from: appButtonData)
    }()
    
    public lazy var appCard: AppCardData? = {
        guard let content = content else {
            return nil
        }
        let cardData: Data
        if let data = Data(base64Encoded: content) {
            cardData = data
        } else if let data = content.data(using: .utf8) {
            cardData = data
        } else {
            return nil
        }
        return try? JSONDecoder().decode(AppCardData.self, from: cardData)
    }()
    
    public lazy var mentionedFullnameReplacedContent = makeMentionedFullnameReplacedContent()
    public lazy var markdownControlCodeRemovedContent = makeMarkdownControlCodeRemovedContent()
    
    public var ownerIsBot: Bool {
        User.isBot(identityNumber: ownerIdentityNumber)
    }
    
    public var isMuted: Bool {
        guard let muteUntil = self.muteUntil else {
            return false
        }
        return muteUntil > Date().toUTCString()
    }
    
    public convenience init(ownerUser: UserItem) {
        self.init()
        conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: ownerUser.userId)
        name = ownerUser.fullName
        iconUrl = ownerUser.avatarUrl
        ownerId = ownerUser.userId
        ownerIdentityNumber = ownerUser.identityNumber
        category = ConversationCategory.CONTACT.rawValue
        contentType = MessageCategory.SIGNAL_TEXT.rawValue
    }
    
    public convenience init(response: ConversationResponse) {
        self.init()
        conversationId = response.conversationId
        ownerId = response.creatorId
        category = response.category
        name = response.name
        iconUrl = response.iconUrl
        announcement = response.announcement
        status = ConversationStatus.SUCCESS.rawValue
        muteUntil = response.muteUntil
        codeUrl = response.codeUrl
        createdAt = response.createdAt
        expireIn = response.expireIn
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.conversationId = try container.decode(String.self, forKey: .conversationId)
        self.ownerId = (try? container.decodeIfPresent(String.self, forKey: .ownerId)) ?? ""
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        self.iconUrl = (try? container.decodeIfPresent(String.self, forKey: .iconUrl)) ?? ""
        self.announcement = (try? container.decodeIfPresent(String.self, forKey: .announcement)) ?? ""
        self.lastReadMessageId = try container.decodeIfPresent(String.self, forKey: .lastReadMessageId)
        self.unseenMessageCount = (try? container.decodeIfPresent(Int.self, forKey: .unseenMessageCount)) ?? 0
        self.unseenMentionCount = (try? container.decodeIfPresent(Int.self, forKey: .unseenMentionCount)) ?? 0
        self.status = (try? container.decodeIfPresent(Int.self, forKey: .status)) ?? ConversationStatus.START.rawValue
        self.muteUntil = try container.decodeIfPresent(String.self, forKey: .muteUntil)
        self.codeUrl = try container.decodeIfPresent(String.self, forKey: .codeUrl)
        self.pinTime = try container.decodeIfPresent(String.self, forKey: .pinTime)
        self.expireIn = (try container.decodeIfPresent(Int64.self, forKey: .expireIn)) ?? 0
        self.createdAt = (try? container.decodeIfPresent(String.self, forKey: .createdAt)) ?? ""
        
        self.ownerIdentityNumber = (try? container.decodeIfPresent(String.self, forKey: .ownerIdentityNumber)) ?? ""
        self.ownerFullName = (try? container.decodeIfPresent(String.self, forKey: .ownerFullName)) ?? ""
        self.ownerAvatarUrl = (try? container.decodeIfPresent(String.self, forKey: .ownerAvatarUrl)) ?? ""
        self.ownerIsVerified = (try? container.decodeIfPresent(Bool.self, forKey: .ownerIsVerified)) ?? false
        self.ownerMembership = try? container.decodeIfPresent(User.Membership.self, forKey: .ownerMembership)
        
        self.messageStatus = (try? container.decodeIfPresent(String.self, forKey: .messageStatus)) ?? ""
        self.messageId = (try? container.decodeIfPresent(String.self, forKey: .messageId)) ?? ""
        self.content = (try? container.decodeIfPresent(String.self, forKey: .content))
        self.contentType = (try? container.decodeIfPresent(String.self, forKey: .contentType)) ?? ""
        self.contentExpireIn = (try container.decodeIfPresent(Int64.self, forKey: .contentExpireIn)) ?? 0
        
        self.senderId = (try? container.decodeIfPresent(String.self, forKey: .senderId)) ?? ""
        self.senderFullName = (try? container.decodeIfPresent(String.self, forKey: .senderFullName)) ?? ""
        
        self.participantFullName = try container.decodeIfPresent(String.self, forKey: .participantFullName)
        self.participantUserId = try container.decodeIfPresent(String.self, forKey: .participantUserId)
        
        self.appId = try container.decodeIfPresent(String.self, forKey: .appId)
        self.actionName = try container.decodeIfPresent(String.self, forKey: .actionName)
        
        self.mentionsJson = try container.decodeIfPresent(Data.self, forKey: .mentionsJson)
    }
    
    internal init(conversationId: String = "", ownerId: String = "", category: String? = nil, name: String = "", iconUrl: String = "", announcement: String = "", lastReadMessageId: String? = nil, unseenMessageCount: Int = 0, unseenMentionCount: Int = 0, status: Int = ConversationStatus.START.rawValue, muteUntil: String? = nil, codeUrl: String? = nil, pinTime: String? = nil, createdAt: String = "", ownerIdentityNumber: String = "", ownerFullName: String = "", ownerAvatarUrl: String = "", ownerIsVerified: Bool = false, messageStatus: String = "", messageId: String = "", content: String = "", contentType: String = "", senderId: String = "", senderFullName: String = "", participantFullName: String? = nil, participantUserId: String? = nil, appId: String? = nil, actionName: String? = nil, mentionsJson: Data? = nil) {
        self.conversationId = conversationId
        self.ownerId = ownerId
        self.category = category
        self.name = name
        self.iconUrl = iconUrl
        self.announcement = announcement
        self.lastReadMessageId = lastReadMessageId
        self.unseenMessageCount = unseenMessageCount
        self.unseenMentionCount = unseenMentionCount
        self.status = status
        self.muteUntil = muteUntil
        self.codeUrl = codeUrl
        self.pinTime = pinTime
        self.createdAt = createdAt
        self.ownerIdentityNumber = ownerIdentityNumber
        self.ownerFullName = ownerFullName
        self.ownerAvatarUrl = ownerAvatarUrl
        self.ownerIsVerified = ownerIsVerified
        self.messageStatus = messageStatus
        self.messageId = messageId
        self.content = content
        self.contentType = contentType
        self.senderId = senderId
        self.senderFullName = senderFullName
        self.participantFullName = participantFullName
        self.participantUserId = participantUserId
        self.appId = appId
        self.actionName = actionName
        self.mentionsJson = mentionsJson
    }
    
    public func getConversationName() -> String {
        guard category == ConversationCategory.CONTACT.rawValue else {
            return name
        }
        return ownerFullName
    }
    
    public func isGroup() -> Bool {
        return category == ConversationCategory.GROUP.rawValue
    }
    
    public func isNeedCachedGroupIcon() -> Bool {
        return category == ConversationCategory.GROUP.rawValue && (iconUrl.isEmpty || !FileManager.default.fileExists(atPath: AppGroupContainer.groupIconsUrl.appendingPathComponent(iconUrl).path))
    }
    
}

extension ConversationItem: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case conversationId
        case ownerId
        case iconUrl
        case announcement
        case category
        case name
        case status
        case lastReadMessageId
        case unseenMessageCount
        case unseenMentionCount
        case muteUntil
        case codeUrl
        case pinTime
        case expireIn
        case content
        case contentType
        case contentExpireIn
        case createdAt
        case senderId
        case senderFullName
        case ownerIdentityNumber
        case ownerFullName
        case ownerAvatarUrl
        case ownerIsVerified
        case ownerMembership
        case actionName
        case participantFullName
        case participantUserId
        case messageStatus
        case messageId
        case appId
        case mentionsJson = "mentions"
    }
    
}

extension ConversationItem: MarkdownControlCodeRemovable {
    
    var contentBeforeRemovingMarkdownControlCode: String? {
        content
    }
    
    var isPostContent: Bool {
        contentType.hasSuffix("_POST")
    }
    
}

extension ConversationItem: MentionedFullnameReplaceable {
    
    public var contentBeforeReplacingMentionedFullname: String? {
        content
    }
    
}
