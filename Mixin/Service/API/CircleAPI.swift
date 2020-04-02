import UIKit
import MixinServices

final class CircleAPI: BaseAPI {
    
    private enum Url {
        static let circles = "circles"
        static func update(id: String) -> String {
            "circles/\(id)"
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
    
    func updateCircle(of id: String, members: [CircleMember], completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        let params = members.map({ member -> [String: String] in
            var param = ["conversation_id": member.conversationId]
            if member.category == ConversationCategory.CONTACT.rawValue {
                param["contact_id"] = member.ownerId
            }
            return param
        })
        request(method: .post, url: Url.conversations(id: id), parameters: params.toParameters(), encoding: JSONArrayEncoding(), completion: completion)
    }
    
    func delete(id: String, completion: @escaping (APIResult<EmptyResponse>) -> Void) {
        request(method: .post, url: Url.delete(id: id), completion: completion)
    }
    
}
