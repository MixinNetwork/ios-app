import MixinServices

public final class ExternalSchemeAPI: MixinAPI {

    private enum Path {
        static let schemes = "/external/schemes"
        
        static func address(assetId: String, destination: String, tag: String?)  -> String {
            var path = "/external/addresses/check?asset=\(assetId)&destination=\(destination)"
            if let tag {
                path += "&tag=\(tag)"
            }
            return path
        }
    }
    
    public static func schemes(completion: @escaping (MixinAPI.Result<[String]>) -> Void) {
        request(method: .get, path: Path.schemes, completion: completion)
    }
    
    public static func addressFee(assetId: String, destination: String, tag: String?) -> MixinAPI.Result<AddressFeeResponse> {
        request(method: .get, path: Path.address(assetId: assetId, destination: destination, tag: tag))
    }
    
}
