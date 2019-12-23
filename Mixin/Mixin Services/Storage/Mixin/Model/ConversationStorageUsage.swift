import Foundation
import WCDBSwift

public class ConversationStorageUsage: TableCodable {

    public var conversationId: String = ""
    public var ownerId: String = ""
    public var category: String? = nil
    public var name: String = ""
    public var iconUrl: String = ""

    public var ownerIdentityNumber: String = ""
    public var ownerFullName: String = ""
    public var ownerAvatarUrl: String = ""
    public var ownerIsVerified = false

    public var mediaSize: Int64 = 0

    public enum CodingKeys: String, CodingTableKey {
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        public typealias Root = ConversationStorageUsage

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

    public func getConversationName() -> String {
        guard category == ConversationCategory.CONTACT.rawValue else {
            return name
        }
        return ownerFullName
    }

}
