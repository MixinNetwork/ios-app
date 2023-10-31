import Alamofire

public final class NetworkAPI: MixinAPI {
    
    public static func chain(id: String) -> MixinAPI.Result<Chain> {
        request(method: .get, path: "/network/chains/" + id)
    }
    
    public static func chain(id: String, completion: @escaping (MixinAPI.Result<Chain>) -> Void) {
        request(method: .get, path: "/network/chains/" + id, completion: completion)
    }
    
    public static func chain(id: String) async throws -> Chain {
        try await request(method: .get, path: "/network/chains/" + id)
    }
    
    public static func chains() async throws -> [Chain] {
        try await request(method: .get, path: "/network/chains")
    }
    
}
