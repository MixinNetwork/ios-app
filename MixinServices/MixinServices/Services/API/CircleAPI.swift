import Foundation

class CircleAPI: MixinAPI {
    
    private enum Path {
        static func circle(id: String) -> String {
            "/circles/\(id)"
        }
    }
    
    static func circle(id: String) -> MixinAPI.Result<CircleResponse> {
        return request(method: .get, path: Path.circle(id: id))
    }
    
    static func circle(id: String, completion: @escaping (MixinAPI.Result<CircleResponse>) -> Void) {
        request(method: .get, path: Path.circle(id: id), completion: completion)
    }
    
}
