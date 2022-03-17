import MixinServices

public final class ExternalSchemeAPI: MixinAPI {

    private enum Path {
        static let schemes = "/external/schemes"
    }
    
    public static func schemes(completion: @escaping (MixinAPI.Result<[String]>) -> Void) {
        request(method: .get, path: Path.schemes, completion: completion)
    }
    
}
