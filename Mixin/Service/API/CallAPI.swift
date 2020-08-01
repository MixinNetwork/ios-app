import MixinServices

final class CallAPI: MixinAPI {
    
    static let shared = CallAPI()
    
    private enum url {
        static let turn = "turn"
    }
    
    func turn(completion: @escaping (MixinAPI.Result<[TurnServer]>) -> Void) {
        request(method: .get, url: url.turn, completion: completion)
    }

    func turn() -> MixinAPI.Result<[TurnServer]> {
        return request(method: .get, url: url.turn)
    }
    
}
