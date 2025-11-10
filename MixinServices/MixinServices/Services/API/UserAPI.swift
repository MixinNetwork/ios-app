import MixinServices
import Alamofire

public final class UserAPI: MixinAPI {
    
    private enum Path {
        static func search(keyword: String) -> String {
            return "/search/" + keyword
        }
        static func codes(codeId: String) -> String {
            return "/codes/" + codeId
        }
        static func getUser(id: String) -> String {
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
        static let fetchUsers = "/users/fetch"
        static let relationships = "/relationships"
        static let reports = "/reports"
        static let blockingUsers = "/blocking_users"
        static let fetchSessions = "/sessions/fetch"
    }
    
    public static func codes(codeId: String, completion: @escaping (MixinAPI.Result<QRCodeResponse>) -> Void) {
        request(method: .get, path: Path.codes(codeId: codeId), completion: completion)
    }
    
    public static func syncBlockingUsers() {
        request(method: .get, path: Path.blockingUsers) { (result: MixinAPI.Result<[UserResponse]>) in
            if case let .success(users) = result {
                UserDAO.shared.updateUsers(users: users)
            }
        }
    }
    
    @discardableResult
    public static func showUser(userId: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) -> Request? {
        return request(method: .get, path: Path.getUser(id: userId), completion: completion)
    }
    
    public static func showUser(userId: String) -> MixinAPI.Result<UserResponse> {
        request(method: .get, path: Path.getUser(id: userId))
    }
    
    public static func showUsers(userIds: [String]) -> MixinAPI.Result<[UserResponse]> {
        request(method: .post, path: Path.fetchUsers, parameters: userIds).map { (responses: [UserResponse]) in
            // `is_deactivated` is invalid from this endpoint
            responses.map(\.deactivationIgnored)
        }
    }
    
    @discardableResult
    public static func showUsers(userIds: [String], completion: @escaping (MixinAPI.Result<[UserResponse]>) -> Void) -> Request? {
        request(method: .post, path: Path.fetchUsers, parameters: userIds) { result in
            // `is_deactivated` is invalid from this endpoint
            let deactivationIgnoredResult = result.map { (responses: [UserResponse]) in
                responses.map(\.deactivationIgnored)
            }
            completion(deactivationIgnoredResult)
        }
    }
    
    public static func user(userID: String) async throws -> UserResponse {
        try await withCheckedThrowingContinuation { continuation in
            showUser(userId: userID, completion: continuation.resume(with:))
        }
    }
    
    @discardableResult
    public static func search(keyword: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) -> Request? {
        return request(method: .get, path: Path.search(keyword: keyword), completion: completion)
    }
    
    public static func search(keyword: String) -> MixinAPI.Result<UserResponse> {
        return request(method: .get, path: Path.search(keyword: keyword))
    }
    
    public static func addFriend(userId: String, fullName: String?) -> MixinAPI.Result<UserResponse> {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: fullName, action: .ADD)
        return request(method: .post, path: Path.relationships, parameters: relationshipRequest)
    }
    
    public static func addFriend(userId: String, fullName: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: fullName, action: .ADD)
        request(method: .post, path: Path.relationships, parameters: relationshipRequest, completion: completion)
    }
    
    public static func removeFriend(userId: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .REMOVE)
        request(method: .post, path: Path.relationships, parameters: relationshipRequest, completion: completion)
    }
    
    public static func remarkFriend(userId: String, full_name: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: full_name, action: .UPDATE)
        request(method: .post, path: Path.relationships, parameters: relationshipRequest, completion: completion)
    }
    
    public static func blockUser(userId: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        request(method: .post, path: Path.relationships, parameters: relationshipRequest, completion: completion)
    }
    
    public static func blockUser(userId: String) -> MixinAPI.Result<UserResponse> {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        return request(method: .post, path: Path.relationships, parameters: relationshipRequest)
    }
    
    public static func reportUser(userId: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        request(method: .post, path: Path.reports, parameters: relationshipRequest, completion: completion)
    }
    
    public static func reportUser(userId: String) -> MixinAPI.Result<UserResponse> {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .BLOCK)
        return request(method: .post, path: Path.reports, parameters: relationshipRequest)
    }
    
    public static func unblockUser(userId: String, completion: @escaping (MixinAPI.Result<UserResponse>) -> Void) {
        let relationshipRequest = RelationshipRequest(user_id: userId, full_name: nil, action: .UNBLOCK)
        request(method: .post, path: Path.relationships, parameters: relationshipRequest, completion: completion)
    }
    
    public static func getFavoriteApps(ofUserWith id: String, completion: @escaping (MixinAPI.Result<[FavoriteApp]>) -> Void) {
        request(method: .get, path: Path.getFavorite(userId: id), completion: completion)
    }
    
    public static func setFavoriteApp(id: String, completion: @escaping (MixinAPI.Result<FavoriteApp>) -> Void) {
        request(method: .post, path: Path.setFavorite(appId: id), completion: completion)
    }
    
    public static func unfavoriteApp(id: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .post, path: Path.unfavorite(appId: id), completion: completion)
    }
    
    public static func fetchSessions(userIds: [String]) -> MixinAPI.Result<[UserSession]> {
        request(method: .post, path: Path.fetchSessions, parameters: userIds)
    }
    
}
