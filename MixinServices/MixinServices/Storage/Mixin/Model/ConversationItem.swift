import Foundation
import WCDBSwift

public class ConversationItem: TableCodable {
    
    public var conversationId: String = ""
    public var ownerId: String = ""
    public var category: String? = nil
    public var name: String = ""
    public var iconUrl: String = ""
    public var announcement: String = ""
    public var lastReadMessageId: String? = nil
    public var unseenMessageCount: Int = 0
    public var status: Int = ConversationStatus.START.rawValue
    public var muteUntil: String? = nil
    public var codeUrl: String? = nil
    public var pinTime: String? = nil
    public var createdAt: String = ""
    
    public var ownerIdentityNumber: String = ""
    public var ownerFullName: String = ""
    public var ownerAvatarUrl: String = ""
    public var ownerIsVerified = false
    
    public var messageStatus: String = ""
    public var messageId: String = ""
    public var content: String = ""
    public var contentType: String = ""
    
    public var senderId: String = ""
    public var senderFullName: String = ""
    
    public var participantFullName: String? = nil
    public var participantUserId: String? = nil
    
    public var appId: String? = nil
    public var actionName: String? = nil
    
    public lazy var appButtons: [AppButtonData]? = {
        guard let data = Data(base64Encoded: content) else {
            return nil
        }
        return try? JSONDecoder().decode([AppButtonData].self, from: data)
    }()
    
    public lazy var appCard: AppCardData? = {
        guard let data = Data(base64Encoded: content) else {
            return nil
        }
        return try? JSONDecoder().decode(AppCardData.self, from: data)
    }()
    
    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = ConversationItem
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        case conversationId
        case ownerId
        case iconUrl
        case announcement
        case category
        case name
        case status
        case lastReadMessageId
        case unseenMessageCount
        case muteUntil
        case codeUrl
        case pinTime
        case content
        case contentType
        case createdAt
        case senderId
        case senderFullName
        case ownerIdentityNumber
        case ownerFullName
        case ownerAvatarUrl
        case ownerIsVerified
        case actionName
        case participantFullName
        case participantUserId
        case messageStatus
        case messageId
        case appId
        
    }
    
    public var ownerIsBot: Bool {
        return !(appId?.isEmpty ?? true)
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
