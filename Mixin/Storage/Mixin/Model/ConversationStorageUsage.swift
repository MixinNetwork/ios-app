import Foundation
import WCDBSwift

class ConversationStorageUsage: TableCodable {

    var conversationId: String = ""
    var ownerId: String = ""
    var category: String? = nil
    var name: String = ""
    var iconUrl: String = ""

    var ownerIdentityNumber: String = ""
    var ownerFullName: String = ""
    var ownerAvatarUrl: String = ""
    var ownerIsVerified = false

    var mediaSize: Int64 = 0

    enum CodingKeys: String, CodingTableKey {
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        typealias Root = ConversationStorageUsage

        case conversationId
        case ownerId
        case category
        case iconUrl
        case name

        case ownerIdentityNumber
        case ownerFullName
        case ownerAvatarUrl
        case ownerIsVerified

        case mediaSize
    }

    func getConversationName() -> String {
        guard category == ConversationCategory.CONTACT.rawValue else {
            return name
        }
        return ownerFullName
    }

}
