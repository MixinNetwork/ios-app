import Foundation
import Alamofire

public class ConversationAPI : MixinAPI {
    
    private enum Path {
        static let conversations = "/conversations"
        static func conversations(id: String) -> String {
            return "/conversations/\(id)"
        }
        
        static func participants(id: String, action: ParticipantAction) -> String {
            return "/conversations/\(id)/participants/\(action.rawValue)"
        }
        
        static func exit(id: String) -> String {
            return "/conversations/\(id)/exit"
        }
        
        static func join(codeId: String) -> String {
            return "/conversations/\(codeId)/join"
        }
        
        static func mute(conversationId: String) -> String {
            return "/conversations/\(conversationId)/mute"
        }
        
        static func reset(conversationId: String) -> String {
            return "/conversations/\(conversationId)/rotate"
        }
        
    }
    
    public static func createConversation(
        conversation: CreateConversationRequest,
        completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void,
    ) {
        request(method: .post, path: Path.conversations, parameters: conversation, completion: completion)
    }
    
    public static func createConversation(conversation: CreateConversationRequest) -> MixinAPI.Result<ConversationResponse> {
        return request(method: .post, path: Path.conversations, parameters: conversation)
    }
    
    public static func getConversation(conversationId: String) -> MixinAPI.Result<ConversationResponse> {
        return request(method: .get, path: Path.conversations(id: conversationId))
    }
    
    public static func exitConversation(conversationId: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, path: Path.exit(id: conversationId), completion: completion)
    }
    
    public static func joinConversation(codeId: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        request(method: .post, path: Path.join(codeId: codeId), completion: completion)
    }
    
    public static func addParticipant(conversationId: String, participantUserIds: [String], completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        let parameters = participantUserIds.map({ ["user_id": $0, "role": ""] })
        request(method: .post, path: Path.participants(id: conversationId, action: ParticipantAction.ADD), parameters: parameters, completion: completion)
    }
    
    public static func removeParticipant(conversationId: String, userId: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        let parameters = [["user_id": userId, "role": ""]]
        request(method: .post, path: Path.participants(id: conversationId, action: ParticipantAction.REMOVE), parameters: parameters, completion: completion)
    }
    
    public static func adminParticipant(conversationId: String, userId: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        let parameters = [["user_id": userId, "role": ParticipantRole.ADMIN.rawValue]]
        request(method: .post, path: Path.participants(id: conversationId, action: ParticipantAction.ROLE), parameters: parameters, completion: completion)
    }
    
    public static func dismissAdminParticipant(conversationId: String, userId: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        let parameters = [["user_id": userId, "role": ""]]
        request(method: .post, path: Path.participants(id: conversationId, action: ParticipantAction.ROLE), parameters: parameters, completion: completion)
    }
    
    public static func updateGroupName(conversationId: String, name: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        request(
            method: .post,
            path: Path.conversations(id: conversationId),
            parameters: ["name": name],
            completion: completion,
        )
    }
    
    public static func updateGroupAnnouncement(conversationId: String, announcement: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        request(
            method: .post,
            path: Path.conversations(id: conversationId),
            parameters: ["announcement": announcement],
            completion: completion,
        )
    }
    
    public static func updateGroupIcon(
        conversationID: String,
        icon: String,
        completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void
    ) {
        request(
            method: .post,
            path: Path.conversations(id: conversationID),
            parameters: [
                "icon_base64": icon,
            ],
            completion: completion
        )
    }
    
    public static func mute(
        conversationID: String,
        category: String,
        participants: [ParticipantRequest]?,
        duration: Int64,
        completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void,
    ) {
        var parameters: [String: Any] = [
            "conversation_id": conversationID,
            "category": category,
            "duration": duration,
        ]
        if let participants {
            parameters["participants"] = participants.map {
                ["user_id": $0.userId, "role": $0.role]
            }
        }
        request(
            method: .post,
            path: Path.mute(conversationId: conversationID),
            parameters: parameters,
            completion: completion,
        )
    }
    
    public static func updateCodeId(conversationId: String, completion: @escaping (MixinAPI.Result<ConversationResponse>) -> Void) {
        request(method: .post, path: Path.reset(conversationId: conversationId), completion: completion)
    }
    
    public static func updateExpireIn(
        conversationID: String,
        expireIn: Int64,
        completion: @escaping (MixinAPI.Result<Empty>) -> Void
    ) {
        request(
            method: .post,
            path: "/conversations/\(conversationID)/disappear",
            parameters: ["duration": expireIn],
            completion: completion
        )
    }
    
}
