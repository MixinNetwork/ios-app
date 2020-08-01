import Foundation
import Alamofire

public class ConversationAPI : MixinAPI {
    
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
    
    public static func createConversation(conversation: ConversationRequest, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        request(method: .post, url: url.conversations, parameters: conversation.toParameters(), encoding: EncodableParameterEncoding<ConversationRequest>(), completion: completion)
    }
    
    public static func createConversation(conversation: ConversationRequest) -> MixinAPI.Result<ConversationResponse> {
        return request(method: .post, url: url.conversations, parameters: conversation.toParameters(), encoding: EncodableParameterEncoding<ConversationRequest>())
    }
    
    public static func getConversation(conversationId: String) -> MixinAPI.Result<ConversationResponse> {
        return request(method: .get, url: url.conversations(id: conversationId))
    }
    
    public static func exitConversation(conversationId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, url: url.exit(id: conversationId), completion: completion)
    }
    
    public static func joinConversation(codeId: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        request(method: .post, url: url.join(codeId: codeId), completion: completion)
    }
    
    public static func addParticipant(conversationId: String, participantUserIds: [String], completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        let parameters = participantUserIds.map({ ["user_id": $0, "role": ""] }).toParameters()
        request(method: .post, url: url.participants(id: conversationId, action: ParticipantAction.ADD), parameters: parameters, encoding: JSONArrayEncoding(), completion: completion)
    }
    
    public static func removeParticipant(conversationId: String, userId: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        let parameters = [["user_id": userId, "role": ""]].toParameters()
        request(method: .post, url: url.participants(id: conversationId, action: ParticipantAction.REMOVE), parameters: parameters, encoding: JSONArrayEncoding(), completion: completion)
    }
    
    public static func adminParticipant(conversationId: String, userId: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        let parameters = [["user_id": userId, "role": ParticipantRole.ADMIN.rawValue]].toParameters()
        request(method: .post, url: url.participants(id: conversationId, action: ParticipantAction.ROLE), parameters: parameters, encoding: JSONArrayEncoding(), completion: completion)
    }

    public static func dismissAdminParticipant(conversationId: String, userId: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        let parameters = [["user_id": userId, "role": ""]].toParameters()
        request(method: .post, url: url.participants(id: conversationId, action: ParticipantAction.ROLE), parameters: parameters, encoding: JSONArrayEncoding(), completion: completion)
    }
    
    public static func updateGroupName(conversationId: String, name: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        let conversationRequest = ConversationRequest(conversationId: conversationId, name: name, category: nil, participants: nil, duration: nil, announcement: nil)
        request(method: .post, url: url.conversations(id: conversationId), parameters: conversationRequest.toParameters(), encoding: EncodableParameterEncoding<ConversationRequest>(), completion: completion)
    }
    
    public static func updateGroupAnnouncement(conversationId: String, announcement: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        let conversationRequest = ConversationRequest(conversationId: conversationId, name: nil, category: nil, participants: nil, duration: nil, announcement: announcement)
        request(method: .post, url: url.conversations(id: conversationId), parameters: conversationRequest.toParameters(), encoding: EncodableParameterEncoding<ConversationRequest>(), completion: completion)
    }
    
    public static func mute(conversationId: String, conversationRequest: ConversationRequest, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        request(method: .post, url: url.mute(conversationId: conversationId), parameters: conversationRequest.toParameters(), encoding: EncodableParameterEncoding<ConversationRequest>(), completion: completion)
    }
    
    public static func updateCodeId(conversationId: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        request(method: .post, url: url.reset(conversationId: conversationId), completion: completion)
    }
    
}
