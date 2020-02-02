import Foundation
import Alamofire

open class UserSessionAPI: BaseAPI {

    internal static let shared = UserSessionAPI()

    private enum url {

        static func users(id: String) -> String {
            return "users/\(id)"
        }

        static let users = "users/fetch"
        static let sessionFetch = "sessions/fetch"
    }

    public func fetchSessions(userIds: [String]) -> APIResult<[UserSession]> {
         return request(method: .post, url: url.sessionFetch, parameters: userIds.toParameters(), encoding: JSONArrayEncoding())
    }

    public func showUser(userId: String) -> APIResult<UserResponse> {
        return request(method: .get, url: url.users(id: userId))
    }

    public func showUsers(userIds: [String]) -> APIResult<[UserResponse]> {
        return request(method: .post, url: url.users, parameters: userIds.toParameters(), encoding: JSONArrayEncoding())
    }
    
}
