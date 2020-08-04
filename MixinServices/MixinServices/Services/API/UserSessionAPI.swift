import Foundation
import Alamofire

open class UserSessionAPI: MixinAPI {
    
    private enum url {

        static func users(id: String) -> String {
            return "users/\(id)"
        }

        static let users = "users/fetch"
        static let sessionFetch = "sessions/fetch"
    }

    public static func fetchSessions(userIds: [String]) -> MixinAPI.Result<[UserSession]> {
         return request(method: .post, url: url.sessionFetch, parameters: userIds)
    }

    public static func showUser(userId: String) -> MixinAPI.Result<UserResponse> {
        return request(method: .get, url: url.users(id: userId))
    }

    public static func showUsers(userIds: [String]) -> MixinAPI.Result<[UserResponse]> {
        return request(method: .post, url: url.users, parameters: userIds)
    }
    
}
