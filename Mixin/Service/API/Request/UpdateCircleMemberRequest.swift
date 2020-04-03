import Foundation
import MixinServices

class UpdateCircleMemberRequest: Encodable {
    
    let conversationId: String
    let contactId: String?
    
    var jsonObject: [String: String] {
        var object = ["conversation_id": conversationId]
        if let contactId = contactId {
            object["contact_id"] = contactId
        }
        return object
    }
    
    init(conversationId: String, contactId: String?) {
        self.conversationId = conversationId
        self.contactId = contactId
    }
    
    init(member: CircleMember) {
        self.conversationId = member.conversationId
        if member.category == ConversationCategory.CONTACT.rawValue {
            self.contactId = member.ownerId
        } else {
            self.contactId = nil
        }
    }
    
}
