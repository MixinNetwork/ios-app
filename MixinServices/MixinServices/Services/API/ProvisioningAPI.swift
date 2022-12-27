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
    
    public static func update(id: String, secret: String, pin: String, completion: @escaping (MixinAPI.Result<ProvisioningResponse>) -> Void) {
        let timestamp = UInt64(Date().timeIntervalSince1970) * UInt64(NSEC_PER_SEC)
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.updateProvisioning(id: id, secret: secret)
        }, onFailure: completion) { (encryptedPin) in
            let parameters = ["pin_base64": encryptedPin, "secret": secret]
            request(method: .post, path: Path.update(id: id), parameters: parameters, completion: completion)
        }
    }
    
}
