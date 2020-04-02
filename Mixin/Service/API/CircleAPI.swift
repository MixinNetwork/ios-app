import UIKit
import MixinServices

final class CircleAPI: BaseAPI {
    
    private enum Url {
        static let circles = "/circles"
        static func update(id: String) -> String {
            "/circles/\(id)"
        }
        static func delete(id: String) -> String {
            "/circles/\(id)/delete"
        }
        static func conversations(id: String) -> String {
            "/circles/\(id)/conversations"
        }
    }
    
    static let shared = CircleAPI()
    
    func circles(completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .get, url: Url.circles, completion: completion)
    }
    
    func create(completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: Url.circles, completion: completion)
    }
    
    func update(id: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: Url.update(id: id), completion: completion)
    }
    
    func delete(id: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: Url.delete(id: id), completion: completion)
    }
    
    func conversations(of circleId: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: Url.conversations(id: circleId), completion: completion)
    }
    
}
