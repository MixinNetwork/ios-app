import MixinServices

final class CallAPI: BaseAPI {
    
    static let shared = CallAPI()
    
    private enum url {
        static let turn = "turn"
    }
    
    func turn(completion: @escaping (BaseAPI.Result<[TurnServer]>) -> Void) {
        request(method: .get, url: url.turn, completion: completion)
    }
    
}
