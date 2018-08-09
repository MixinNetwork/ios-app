import Foundation
import Alamofire

final class UserAPI: BaseAPI {

    static let shared = UserAPI()

    private enum url {
        static func search(keyword: String) -> String {
            return "search/" + keyword
        }
        static func codes(codeId: String) -> String {
            return "codes/" + codeId
        }
        static func users(id: String) -> String {
            return "users/\(id)"
        }
        static let users = "users/fetch"
        static let relationships = "relationships"
    }

    func codes(codeId: String, completion: @escaping (APIResult<QRCodeResponse>) -> Void) {
        request(method: .get, url: url.codes(codeId: codeId), toastError: false, completion: completion)
    }

    @discardableResult
    func showUser(userId: String, completion: @escaping (APIResult<UserResponse>) -> Void) -> Request? {
        return request(method: .get, url: url.users(id: userId), completion: completion)
    }

    func showUser(userId: String) -> APIResult<UserResponse> {
        return request(method: .get, url: url.users(id: userId))
    }

    @discardableResult
    func showUsers(userIds: [String], completion: @escaping (APIResult<[UserResponse]>) -> Void) -> Request? {
        return request(method: .post, url: url.users, parameters: userIds.toParameters(), encoding: JSONArrayEncoding(), completion: completion)
    }

    func showUsers(userIds: [String]) -> APIResult<[UserResponse]> {
        return request(method: .post, url: url.users, parameters: userIds.toParameters(), encoding: JSONArrayEncoding())
    }

    func search(keyword: String, completion: @escaping (APIResult<UserResponse>) -> Void) {
        request(method: .get, url: url.search(keyword: keyword), toastError: false, completion: completion)
    }

    func search(keyword: String) -> APIResult<UserResponse> {
        return request(method: .get, url: url.search(keyword: keyword))
    }

    func addFriend(userId: String, full_name: String, completion: @escaping (APIResult<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: full_name, action: .ADD)
        request(method: .post, url: url.relationships, parameters: relationshipRequest.toParameters(), encoding: EncodableParameterEncoding<RelationshipRequest>(), completion: completion)
    }

    func removeFriend(userId: String, completion: @escaping (APIResult<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .REMOVE)
        request(method: .post, url: url.relationships, parameters: relationshipRequest.toParameters(), encoding: EncodableParameterEncoding<RelationshipRequest>(), completion: completion)
    }

    func remarkFriend(userId: String, full_name: String, completion: @escaping (APIResult<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: full_name, action: .UPDATE)
        request(method: .post, url: url.relationships, parameters: relationshipRequest.toParameters(), encoding: EncodableParameterEncoding<RelationshipRequest>(), completion: completion)
    }

    func blockUser(userId: String, completion: @escaping (APIResult<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        request(method: .post, url: url.relationships, parameters: relationshipRequest.toParameters(), encoding: EncodableParameterEncoding<RelationshipRequest>(), completion: completion)
    }

    func unblockUser(userId: String, completion: @escaping (APIResult<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .UNBLOCK)
        request(method: .post, url: url.relationships, parameters: relationshipRequest.toParameters(), encoding: EncodableParameterEncoding<RelationshipRequest>(), completion: completion)
    }
}

