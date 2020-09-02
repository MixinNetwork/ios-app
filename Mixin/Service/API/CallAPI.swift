import MixinServices

final class CallAPI: MixinAPI {
    
    private enum url {
        static let turn = "turn"
    }
    
    static func turn(completion: @escaping (MixinAPI.Result<[TurnServer]>) -> Void) {
        request(method: .get, url: url.turn, completion: completion)
    }

    static func turn() -> MixinAPI.Result<[TurnServer]> {
        return request(method: .get, url: url.turn)
    }
    
}
