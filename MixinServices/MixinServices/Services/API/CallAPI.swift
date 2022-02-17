import MixinServices

public final class CallAPI: MixinAPI {
    
    private enum Path {
        static let turn = "/turn"
    }
    
    public static func turn(queue: DispatchQueue = .main, completion: @escaping (MixinAPI.Result<[TurnServer]>) -> Void) {
        request(method: .get, path: Path.turn, queue: queue, completion: completion)
    }
    
    public static func turn() -> MixinAPI.Result<[TurnServer]> {
        return request(method: .get, path: Path.turn)
    }
    
}
