import Foundation

class CircleAPI: MixinAPI {

    private enum Url {
        static func circle(id: String) -> String {
            "circles/\(id)"
        }
    }

    static let shared = CircleAPI()

    func circle(id: String) -> MixinAPI.Result<CircleResponse> {
        return request(method: .get, url: Url.circle(id: id))
    }

    func circle(id: String, completion: @escaping (MixinAPI.Result<CircleResponse>) -> Void) {
        request(method: .get, url: Url.circle(id: id), completion: completion)
    }
}
