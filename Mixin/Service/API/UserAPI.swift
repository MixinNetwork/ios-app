import MixinServices
import Alamofire

final class UserAPI: UserSessionAPI {
    
    private enum Path {
        static func search(keyword: String) -> String {
            return "/search/" + keyword
        }
        static func codes(codeId: String) -> String {
            return "/codes/" + codeId
        }
        static func users(id: String) -> String {
            return "/users/\(id)"
        }
        static func getFavorite(userId: String) -> String {
            return "/users/\(userId)/apps/favorite"
        }
        static func setFavorite(appId: String) -> String {
            return "/apps/\(appId)/favorite"
        }
        static func unfavorite(appId: String) -> String {
            return "/apps/\(appId)/unfavorite"
        }
        static let users = "/users/fetch"
        static let relationships = "/relationships"
        static let reports = "/reports"
        static let blockingUsers = "/blocking_users"
        static let sessionFetch = "/sessions/fetch"
    }
    
    static func codes(codeId: String, completion: @escaping (MixinAPI.Result<QRCodeResponse>) -> Void) {
        request(method: .get, path: Path.codes(codeId: codeId), completion: completion)
    }
    
    @discardableResult
    static func showUser(userId: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) -> Request? {
        return request(method: .get, path: Path.users(id: userId), completion: completion)
    }
    
    static func syncBlockingUsers() {
        request(method: .get, path: Path.blockingUsers) { (result: MixinAPI.Result<[UserResponse]>) in
            if case let .success(users) = result {
                UserDAO.shared.updateUsers(users: users)
            }
        }
    }
    
    @discardableResult
    static func showUsers(userIds: [String], completion: @escaping (MixinAPI.Result<[UserResponse]>) -> Void) -> Request? {
        return request(method: .post, path: Path.users, parameters: userIds, completion: completion)
    }
    
    @discardableResult
    static func search(keyword: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) -> Request? {
        return request(method: .get, path: Path.search(keyword: keyword), completion: completion)
    }
    
    static func search(keyword: String) -> MixinAPI.Result<UserResponse> {
        return request(method: .get, path: Path.search(keyword: keyword))
    }
    
    static func addFriend(userId: String, full_name: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: full_name, action: .ADD)
        request(method: .post, path: Path.relationships, parameters: relationshipRequest, completion: completion)
    }
    
    static func removeFriend(userId: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .REMOVE)
        request(method: .post, path: Path.relationships, parameters: relationshipRequest, completion: completion)
    }
    
    static func remarkFriend(userId: String, full_name: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: full_name, action: .UPDATE)
        request(method: .post, path: Path.relationships, parameters: relationshipRequest, completion: completion)
    }
    
    static func blockUser(userId: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        request(method: .post, path: Path.relationships, parameters: relationshipRequest, completion: completion)
    }
    
    static func blockUser(userId: String) -> MixinAPI.Result<UserResponse> {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        return request(method: .post, path: Path.relationships, parameters: relationshipRequest)
    }
    
    static func reportUser(userId: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        request(method: .post, path: Path.reports, parameters: relationshipRequest, completion: completion)
    }
    
    static func reportUser(userId: String) -> MixinAPI.Result<UserResponse> {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        return request(method: .post, path: Path.reports, parameters: relationshipRequest)
    }
    
    static func unblockUser(userId: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .UNBLOCK)
        request(method: .post, path: Path.relationships, parameters: relationshipRequest, completion: completion)
    }
    
    static func getFavoriteApps(ofUserWith id: String, completion: @escaping (MixinAPI.Result<[FavoriteApp]>) -> Void) {
        request(method: .get, path: Path.getFavorite(userId: id), completion: completion)
    }
    
    static func setFavoriteApp(id: String, completion: @escaping (MixinAPI.Result<FavoriteApp>) -> Void) {
        request(method: .post, path: Path.setFavorite(appId: id), completion: completion)
    }
    
    static func unfavoriteApp(id: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, path: Path.unfavorite(appId: id), completion: completion)
    }
    
}
