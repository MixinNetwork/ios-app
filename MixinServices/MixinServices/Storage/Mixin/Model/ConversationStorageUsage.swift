import Foundation
import GRDB

public final class ConversationStorageUsage: Decodable, MixinFetchableRecord {
    
    public var conversationId: String
    public var ownerId: String?
    public var category: String?
    public var name: String?
    public var iconUrl: String?
    
    public var ownerIdentityNumber: String
    public var ownerFullName: String?
    public var ownerAvatarUrl: String?
    public var ownerIsVerified: Bool?
    
    public var mediaSize: Int64?
    
    public func getConversationName() -> String {
        guard category == ConversationCategory.CONTACT.rawValue else {
            return name ?? ""
        }
        return ownerFullName ?? ""
    }
    
}
