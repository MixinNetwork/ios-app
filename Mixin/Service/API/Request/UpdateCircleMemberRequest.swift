import Foundation
import MixinServices

class UpdateCircleMemberRequest: Encodable {
    
    let conversationId: String
    let userId: String?
    
    var jsonObject: [String: String] {
        var object = ["conversation_id": conversationId]
        if let userId = userId {
            object["user_id"] = userId
        }
        return object
    }
    
    init(conversationId: String, userId: String?) {
        self.conversationId = conversationId
        self.userId = userId
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
