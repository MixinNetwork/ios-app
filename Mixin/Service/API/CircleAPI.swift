import UIKit
import Alamofire
import MixinServices

final class CircleAPI: BaseAPI {
    
    private enum Url {
        static let circles = "circles"
        static func update(id: String) -> String {
            "circles/\(id)"
        }
        static func updateCircleForConversation(id: String) -> String {
            "conversations/\(id)/circles"
        }
        static func updateCircleForUser(id: String) -> String {
            "users/\(id)/circles"
        }
        static func delete(id: String) -> String {
            "circles/\(id)/delete"
        }
        static func conversations(id: String) -> String {
            "circles/\(id)/conversations"
        }
        static func conversations(id: String, offset: String?, limit: Int) -> String {
            var url = "circles/\(id)/conversations?limit=\(limit)"
            if let offset = offset {
                url += "&offset=\(offset)"
            }
            return url
        }
    }
    
    static let shared = CircleAPI()

    func circles() -> BaseAPI.Result<[CircleResponse]> {
        return request(method: .get, url: Url.circles)
    }

    func circleConversations(circleId: String, offset: String?, limit: Int) -> BaseAPI.Result<[CircleConversation]> {
        return request(method: .get, url: Url.conversations(id: circleId, offset: offset, limit: limit))
    }

    func create(name: String, completion: @escaping (BaseAPI.Result<CircleResponse>) -> Void) {
        let param = ["name": name]
        request(method: .post, url: Url.circles, parameters: param, completion: completion)
    }
    
    func update(id: String, name: String, completion: @escaping (BaseAPI.Result<CircleResponse>) -> Void) {
        let param = ["name": name]
        request(method: .post, url: Url.update(id: id), parameters: param, completion: completion)
    }

    func updateCircle(of id: String, requests: [CircleConversationRequest], completion: @escaping (BaseAPI.Result<[CircleConversation]>) -> Void) {
        let params = requests.map(\.jsonObject).toParameters()
        request(method: .post, url: Url.conversations(id: id), parameters: params, encoding: JSONArrayEncoding(), completion: completion)
    }
    
    func updateCircles(forConversationWith id: String, requests: [ConversationCircleRequest], completion: @escaping (BaseAPI.Result<[CircleConversation]>) -> Void) {
        let params = requests.map(\.jsonObject).toParameters()
        request(method: .post, url: Url.updateCircleForConversation(id: id), parameters: params, encoding: JSONArrayEncoding(), completion: completion)
    }
    
    func updateCircles(forUserWith id: String, requests: [ConversationCircleRequest], completion: @escaping (BaseAPI.Result<[CircleConversation]>) -> Void) {
        let params = requests.map(\.jsonObject).toParameters()
        request(method: .post, url: Url.updateCircleForUser(id: id), parameters: params, encoding: JSONArrayEncoding(), completion: completion)
    }
    
    func delete(id: String, completion: @escaping (BaseAPI.Result<Empty>) -> Void) {
        request(method: .post, url: Url.delete(id: id), completion: completion)
    }
    
}
