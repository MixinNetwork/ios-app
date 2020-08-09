import MixinServices

final class CallAPI: MixinAPI {
    
    private enum Path {
        static let turn = "/turn"
    }
    
    static func turn(completion: @escaping (MixinAPI.Result<[TurnServer]>) -> Void) {
        request(method: .get, path: Path.turn, completion: completion)
    }
    
    static func turn() -> MixinAPI.Result<[TurnServer]> {
        return request(method: .get, path: Path.turn)
    }
    
}
