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
        static func getFavorite(userId: String) -> String {
            return "users/\(userId)/apps/favorite"
        }
        static func setFavorite(appId: String) -> String {
            return "apps/\(appId)/favorite"
        }
        static func unfavorite(appId: String) -> String {
            return "apps/\(appId)/unfavorite"
        }
        static let users = "users/fetch"
        static let relationships = "relationships"
        static let reports = "reports"
        static let blockingUsers = "blocking_users"
        static let sessionFetch = "sessions/fetch"
    }

    func fetchSessions(userIds: [String]) -> APIResult<[UserSession]> {
         return request(method: .post, url: url.sessionFetch, parameters: userIds.toParameters(), encoding: JSONArrayEncoding())
    }

    func codes(codeId: String, completion: @escaping (APIResult<QRCodeResponse>) -> Void) {
        request(method: .get, url: url.codes(codeId: codeId), completion: completion)
    }

    @discardableResult
    func showUser(userId: String, completion: @escaping (APIResult<UserResponse>) -> Void) -> Request? {
        return request(method: .get, url: url.users(id: userId), completion: completion)
    }

    func showUser(userId: String) -> APIResult<UserResponse> {
        return request(method: .get, url: url.users(id: userId))
    }

    func syncBlockingUsers() {
        request(method: .get, url: url.blockingUsers) { (result: APIResult<[UserResponse]>) in
            if case let .success(users) = result {
                UserDAO.shared.updateUsers(users: users)
            }
        }
    }

    @discardableResult
    func showUsers(userIds: [String], completion: @escaping (APIResult<[UserResponse]>) -> Void) -> Request? {
        return request(method: .post, url: url.users, parameters: userIds.toParameters(), encoding: JSONArrayEncoding(), completion: completion)
    }

    func showUsers(userIds: [String]) -> APIResult<[UserResponse]> {
        return request(method: .post, url: url.users, parameters: userIds.toParameters(), encoding: JSONArrayEncoding())
    }
    
    @discardableResult
    func search(keyword: String, completion: @escaping (APIResult<UserResponse>) -> Void) -> Request? {
        return request(method: .get, url: url.search(keyword: keyword), completion: completion)
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

    func blockUser(userId: String) -> APIResult<UserResponse> {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        return request(method: .post, url: url.relationships, parameters: relationshipRequest.toParameters(), encoding: EncodableParameterEncoding<RelationshipRequest>())
    }
    
    func reportUser(userId: String, completion: @escaping (APIResult<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        request(method: .post, url: url.reports, parameters: relationshipRequest.toParameters(), encoding: EncodableParameterEncoding<RelationshipRequest>(), completion: completion)
    }
    
    func reportUser(userId: String) -> APIResult<UserResponse> {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        return request(method: .post, url: url.reports, parameters: relationshipRequest.toParameters(), encoding: EncodableParameterEncoding<RelationshipRequest>())
    }

    func unblockUser(userId: String, completion: @escaping (APIResult<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .UNBLOCK)
        request(method: .post, url: url.relationships, parameters: relationshipRequest.toParameters(), encoding: EncodableParameterEncoding<RelationshipRequest>(), completion: completion)
    }
    
    func getFavoriteApps(ofUserWith id: String) -> APIResult<[FavoriteApp]> {
        return request(method: .get, url: url.getFavorite(userId: id))
    }
    
    func getFavoriteApps(ofUserWith id: String, completion: @escaping (APIResult<[FavoriteApp]>) -> Void) {
        request(method: .get, url: url.getFavorite(userId: id), completion: completion)
    }
    
    func setFavoriteApp(id: String, completion: @escaping (APIResult<FavoriteApp>) -> Void) {
        request(method: .post, url: url.setFavorite(appId: id), completion: completion)
    }
    
    func unfavoriteApp(id: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: url.unfavorite(appId: id), completion: completion)
    }
    
}
