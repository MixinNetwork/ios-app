import MixinServices

public final class ExternalAPI: MixinAPI {
    
    public static func schemes(completion: @escaping (MixinAPI.Result<[String]>) -> Void) {
        request(method: .get, path: "/external/schemes", completion: completion)
    }
    
    public static func checkAddress(
        chainID: String,
        assetID: String,
        destination: String,
        tag: String?
    ) async throws -> AddressResponse {
        var path = "/external/addresses/check?asset=\(assetID)&chain=\(chainID)&destination=\(destination)"
        if let tag, !tag.isEmpty {
            path += "&tag=\(tag)"
        }
        return try await request(method: .get, path: path)
    }
    
    public static func fiats(completion: @escaping (MixinAPI.Result<[FiatMoney]>) -> Void) {
        request(method: .get, path: "/external/fiats", completion: completion)
    }
    
}
