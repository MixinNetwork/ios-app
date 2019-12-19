import Foundation
import Alamofire

class ConversationAPI : BaseAPI {
    
    static let shared = ConversationAPI()

    private enum url {
        static let conversations = "conversations"
        static func conversations(id: String) -> String {
            return "conversations/\(id)"
        }

        static func participants(id: String, action: ParticipantAction) -> String {
            return "conversations/\(id)/participants/\(action.rawValue)"
        }

        static func exit(id: String) -> String {
            return "conversations/\(id)/exit"
        }

        static func join(codeId: String) -> String {
            return "conversations/\(codeId)/join"
        }
        
        static func mute(conversationId: String) -> String {
            return "conversations/\(conversationId)/mute"
        }

        static func reset(conversationId: String) -> String {
            return "conversations/\(conversationId)/rotate"
        }

    }

    func createConversation(conversation: ConversationRequest, completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        request(method: .post, url: url.conversations, parameters: conversation.toParameters(), encoding: EncodableParameterEncoding<ConversationRequest>(), completion: completion)
    }

    func createConversation(conversation: ConversationRequest) -> APIResult<ConversationResponse> {
        return request(method: .post, url: url.conversations, parameters: conversation.toParameters(), encoding: EncodableParameterEncoding<ConversationRequest>())
    }

    func getConversation(conversationId: String, completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        request(method: .get, url: url.conversations(id: conversationId), completion: completion)
    }

    func getConversation(conversationId: String) -> APIResult<ConversationResponse> {
        return request(method: .get, url: url.conversations(id: conversationId))
    }

    func exitConversation(conversationId: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: url.exit(id: conversationId), completion: completion)
    }

    func exitConversation(conversationId: String) -> APIResult<EmptyResponse> {
        return request(method: .post, url: url.exit(id: conversationId))
    }

    func joinConversation(codeId: String, completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        request(method: .post, url: url.join(codeId: codeId), completion: completion)
    }

    func addParticipant(conversationId: String, participantUserIds: [String], completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        let parameters = participantUserIds.map({ ["user_id": $0, "role": ""] }).toParameters()
        request(method: .post, url: url.participants(id: conversationId, action: ParticipantAction.ADD), parameters: parameters, encoding: JSONArrayEncoding(), completion: completion)
    }

    func removeParticipant(conversationId: String, userId: String, completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        let parameters = [["user_id": userId, "role": ""]].toParameters()
        request(method: .post, url: url.participants(id: conversationId, action: ParticipantAction.REMOVE), parameters: parameters, encoding: JSONArrayEncoding(), completion: completion)
    }

    func adminParticipant(conversationId: String, userId: String, completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        let parameters = [["user_id": userId, "role": ParticipantRole.ADMIN.rawValue]].toParameters()
        request(method: .post, url: url.participants(id: conversationId, action: ParticipantAction.ROLE), parameters: parameters, encoding: JSONArrayEncoding(), completion: completion)
    }

    func updateGroupName(conversationId: String, name: String, completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        let conversationRequest = ConversationRequest(conversationId: conversationId, name: name, category: nil, participants: nil, duration: nil, announcement: nil)
        request(method: .post, url: url.conversations(id: conversationId), parameters: conversationRequest.toParameters(), encoding: EncodableParameterEncoding<ConversationRequest>(), completion: completion)
    }
    
    func updateGroupAnnouncement(conversationId: String, announcement: String, completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        let conversationRequest = ConversationRequest(conversationId: conversationId, name: nil, category: nil, participants: nil, duration: nil, announcement: announcement)
        request(method: .post, url: url.conversations(id: conversationId), parameters: conversationRequest.toParameters(), encoding: EncodableParameterEncoding<ConversationRequest>(), completion: completion)
    }

    func mute(userId: String, duration: Int64, completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        let conversationId = ConversationDAO.shared.makeConversationId(userId: AccountAPI.shared.accountUserId, ownerUserId: userId)
        mute(conversationId: conversationId, duration: duration, completion: completion)
    }
    
    func mute(conversationId: String, duration: Int64, completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        let conversationRequest = ConversationRequest(conversationId: conversationId, name: nil, category: nil, participants: nil, duration: duration, announcement: nil)
        request(method: .post, url: url.mute(conversationId: conversationId), parameters: conversationRequest.toParameters(), encoding: EncodableParameterEncoding<ConversationRequest>(), completion: completion)
    }

    func updateCodeId(conversationId: String, completion: @escaping (APIResult<ConversationResponse>) -> Void) {
        request(method: .post, url: url.reset(conversationId: conversationId), completion: completion)
    }
}

