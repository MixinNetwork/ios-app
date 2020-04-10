import Foundation

class CircleAPI: BaseAPI {

    private enum Url {
        static func circle(id: String) -> String {
            "circles/\(id)"
        }
    }

    static let shared = CircleAPI()

    func circle(id: String) -> APIResult<CircleResponse> {
        return request(method: .get, url: Url.circle(id: id))
    }
}
