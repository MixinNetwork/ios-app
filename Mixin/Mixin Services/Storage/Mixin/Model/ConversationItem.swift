import Foundation
import WCDBSwift

public class ConversationItem: TableCodable {
    
    var conversationId: String = ""
    var ownerId: String = ""
    var category: String? = nil
    var name: String = ""
    var iconUrl: String = ""
    var announcement: String = ""
    var lastReadMessageId: String? = nil
    var unseenMessageCount: Int = 0
    var status: Int = ConversationStatus.START.rawValue
    var muteUntil: String? = nil
    var codeUrl: String? = nil
    var pinTime: String? = nil
    var createdAt: String = ""
    
    var ownerIdentityNumber: String = ""
    var ownerFullName: String = ""
    var ownerAvatarUrl: String = ""
    var ownerIsVerified = false
    
    var messageStatus: String = ""
    var messageId: String = ""
    var content: String = ""
    var contentType: String = ""
    
    var senderId: String = ""
    var senderFullName: String = ""
    
    var participantFullName: String? = nil
    var participantUserId: String? = nil
    
    var appId: String? = nil
    var actionName: String? = nil
    
    lazy var appButtons: [AppButtonData]? = {
        guard let data = Data(base64Encoded: content) else {
            return nil
        }
        return try? JSONDecoder().decode([AppButtonData].self, from: data)
    }()
    
    lazy var appCard: AppCardData? = {
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
    
    var ownerIsBot: Bool {
        return !(appId?.isEmpty ?? true)
    }
    
    var isMuted: Bool {
        guard let muteUntil = self.muteUntil else {
            return false
        }
        return muteUntil > Date().toUTCString()
    }
    
    convenience init(ownerUser: UserItem) {
        self.init()
        conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: ownerUser.userId)
        name = ownerUser.fullName
        iconUrl = ownerUser.avatarUrl
        ownerId = ownerUser.userId
        ownerIdentityNumber = ownerUser.identityNumber
        category = ConversationCategory.CONTACT.rawValue
        contentType = MessageCategory.SIGNAL_TEXT.rawValue
    }
    
    convenience init(response: ConversationResponse) {
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
    
    func getConversationName() -> String {
        guard category == ConversationCategory.CONTACT.rawValue else {
            return name
        }
        return ownerFullName
    }
    
    func isGroup() -> Bool {
        return category == ConversationCategory.GROUP.rawValue
    }
    
    func isNeedCachedGroupIcon() -> Bool {
        return category == ConversationCategory.GROUP.rawValue && (iconUrl.isEmpty || !FileManager.default.fileExists(atPath: AppGroupContainer.groupIconsUrl.appendingPathComponent(iconUrl).path))
    }
    
}
