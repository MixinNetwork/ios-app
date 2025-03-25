import Foundation
import Alamofire
import MixinServices

public final class AddressAPI: MixinAPI {
    
    public static func address(addressID: String) -> MixinAPI.Result<Address> {
        request(method: .get, path: "/addresses/\(addressID)")
    }
    
    public static func addresses(chainID: String, completion: @escaping (MixinAPI.Result<[Address]>) -> Void) {
        request(method: .get, path: "/safe/addresses?chain=\(chainID)", completion: completion)
    }
    
    public static func save(request: AddressRequest, completion: @escaping (MixinAPI.Result<Address>) -> Void) {
        PINEncryptor.encrypt(pin: request.pin, tipBody: {
            try TIPBody.addAddress(assetID: request.assetID, publicKey: request.destination, keyTag: request.tag, name: request.label)
        }, onFailure: completion) { (encryptedPin) in
            var encryptedRequest = request
            encryptedRequest.pin = encryptedPin
            self.request(method: .post,
                         path: "/addresses",
                         parameters: encryptedRequest,
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
    public static func delete(addressID: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.removeAddress(addressID: addressID)
        }, onFailure: completion) { (encryptedPin) in
            self.request(method: .post,
                         path: "/addresses/\(addressID)/delete",
                         parameters: ["pin_base64": encryptedPin],
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
}
