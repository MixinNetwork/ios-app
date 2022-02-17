import MixinServices

public final class ProvisioningAPI: MixinAPI {
    
    private enum Path {
        static let code = "/device/provisioning/code"
        static func update(id: String) -> String {
            return "/provisionings/" + id
        }
    }
    
    public static func code(completion: @escaping (MixinAPI.Result<ProvisioningCodeResponse>) -> Void) {
        request(method: .get, path: Path.code, completion: completion)
    }
    
    public static func update(id: String, secret: String, completion: @escaping (MixinAPI.Result<ProvisioningResponse>) -> Void) {
        let params = ["secret": secret]
        request(method: .post, path: Path.update(id: id), parameters: params, completion: completion)
    }
    
}
