import Foundation
import WCDBSwift

class ConversationItem: TableCodable {

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

    enum CodingKeys: String, CodingTableKey {
        typealias Root = ConversationItem
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
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
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
        return category == ConversationCategory.GROUP.rawValue && (iconUrl.isEmpty || !FileManager.default.fileExists(atPath: MixinFile.groupIconsUrl.appendingPathComponent(iconUrl).path))
    }

}

extension ConversationItem {

    static func createConversation(from response: ConversationResponse) -> ConversationItem {
        let conversation = ConversationItem()
        conversation.conversationId = response.conversationId
        conversation.ownerId = response.creatorId
        conversation.category = response.category
        conversation.name = response.name
        conversation.iconUrl = response.iconUrl
        conversation.announcement = response.announcement
        conversation.status = ConversationStatus.SUCCESS.rawValue
        conversation.muteUntil = response.muteUntil
        conversation.codeUrl = response.codeUrl
        conversation.createdAt = response.createdAt
        return conversation
    }

}
