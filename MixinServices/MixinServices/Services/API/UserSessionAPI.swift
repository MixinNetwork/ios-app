import Foundation
import Alamofire

open class UserSessionAPI: MixinAPI {

    internal static let shared = UserSessionAPI()

    private enum url {

        static func users(id: String) -> String {
            return "users/\(id)"
        }

        static let users = "users/fetch"
        static let sessionFetch = "sessions/fetch"
    }

    public func fetchSessions(userIds: [String]) -> MixinAPI.Result<[UserSession]> {
         return request(method: .post, url: url.sessionFetch, parameters: userIds.toParameters(), encoding: JSONArrayEncoding())
    }

    public func showUser(userId: String) -> MixinAPI.Result<UserResponse> {
        return request(method: .get, url: url.users(id: userId))
    }

    public func showUsers(userIds: [String]) -> MixinAPI.Result<[UserResponse]> {
        return request(method: .post, url: url.users, parameters: userIds.toParameters(), encoding: JSONArrayEncoding())
    }
    
}
