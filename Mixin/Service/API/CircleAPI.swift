import UIKit
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
    }
    
    static let shared = CircleAPI()
    
    func circles(completion: @escaping (APIResult<[Circle]>) -> Void) {
        request(method: .get, url: Url.circles, completion: completion)
    }
    
    func create(name: String, completion: @escaping (APIResult<CircleResponse>) -> Void) {
        let param = ["name": name]
        request(method: .post, url: Url.circles, parameters: param, completion: completion)
    }
    
    func update(id: String, name: String, completion: @escaping (APIResult<CircleResponse>) -> Void) {
        let param = ["name": name]
        request(method: .post, url: Url.update(id: id), parameters: param, completion: completion)
    }
    
    func updateCircle(of id: String, requests: [UpdateCircleMemberRequest], completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        let params = requests.map(\.jsonObject).toParameters()
        request(method: .post, url: Url.conversations(id: id), parameters: params, encoding: JSONArrayEncoding(), completion: completion)
    }
    
    func updateCircles(with ids: [String], forConversationWith id: String, completion: @escaping (APIResult<[CircleConversation]>) -> Void) {
        let param = ids.map({ ["circle_id": $0] }).toParameters()
        request(method: .post, url: Url.updateCircleForConversation(id: id), parameters: param, encoding: JSONArrayEncoding(), completion: completion)
    }
    
    func updateCircles(with ids: [String], forUserWith id: String, completion: @escaping (APIResult<[CircleConversation]>) -> Void) {
        let param = ids.map({ ["circle_id": $0] }).toParameters()
        request(method: .post, url: Url.updateCircleForUser(id: id), parameters: param, encoding: JSONArrayEncoding(), completion: completion)
    }
    
    func delete(id: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: Url.delete(id: id), completion: completion)
    }
    
}
