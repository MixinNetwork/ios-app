import Foundation
import MixinServices

class UpdateCircleMemberRequest: Encodable {
    
    let conversationId: String
    let userId: String?
    
    var jsonObject: [String: String] {
        var object = ["conversation_id": conversationId]
        if let contactId = userId {
            object["user_id"] = contactId
        }
        return object
    }
    
    init(conversationId: String, contactId: String?) {
        self.conversationId = conversationId
        self.userId = contactId
    }
    
    init(member: CircleMember) {
        self.conversationId = member.conversationId
        if member.category == ConversationCategory.CONTACT.rawValue {
            self.userId = member.userId
        } else {
            self.userId = nil
        }
    }
    
}
