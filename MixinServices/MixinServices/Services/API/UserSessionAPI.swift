import Foundation
import Alamofire

open class UserSessionAPI: MixinAPI {
    
    private enum Path {
        static func users(id: String) -> String {
            "/users/\(id)"
        }
        
        static let fetchUsers = "/users/fetch"
        static let fetchSessions = "/sessions/fetch"
    }
    
    public static func fetchSessions(userIds: [String]) -> MixinAPI.Result<[UserSession]> {
        return request(method: .post, path: Path.fetchSessions, parameters: userIds)
    }
    
    public static func showUser(userId: String) -> MixinAPI.Result<UserResponse> {
        return request(method: .get, path: Path.users(id: userId))
    }
    
    public static func showUsers(userIds: [String]) -> MixinAPI.Result<[UserResponse]> {
        return request(method: .post, path: Path.fetchUsers, parameters: userIds)
    }
    
}
