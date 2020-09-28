import Alamofire
import MixinServices

final class WithdrawalAPI: MixinAPI {
    
    private enum Path {
        static func addresses(assetId: String) -> String {
            "/assets/\(assetId)/addresses"
        }
        
        static let addresses = "/addresses"
        static func address(addressId: String) -> String {
            "/addresses/\(addressId)"
        }
        
        static let withdrawals = "/withdrawals"
        static func delete(addressId: String) -> String {
            "/addresses/\(addressId)/delete"
        }
    }
    
    static func address(addressId: String) -> MixinAPI.Result<Address> {
        return request(method: .get, path: Path.address(addressId: addressId))
    }
    
    static func address(addressId: String, completion: @escaping (MixinAPI.Result<Address>) -> Void) {
        request(method: .get, path: Path.address(addressId: addressId), completion: completion)
    }
    
    static func addresses(assetId: String, completion: @escaping (MixinAPI.Result<[Address]>) -> Void) {
        request(method: .get, path: Path.addresses(assetId: assetId), completion: completion)
    }
    
    static func save(address: AddressRequest, completion: @escaping (MixinAPI.Result<Address>) -> Void) {
        PINEncryptor.encrypt(pin: address.pin, onFailure: completion) { (encryptedPin) in
            var address = address
            address.pin = encryptedPin
            self.request(method: .post,
                         path: Path.addresses,
                         parameters: address,
                         completion: completion)
        }
    }
    
    static func withdrawal(withdrawal: WithdrawalRequest, completion: @escaping (MixinAPI.Result<Snapshot>) -> Void) {
        PINEncryptor.encrypt(pin: withdrawal.pin, onFailure: completion) { (encryptedPin) in
            var withdrawal = withdrawal
            withdrawal.pin = encryptedPin
            self.request(method: .post,
                         path: Path.withdrawals,
                         parameters: withdrawal,
                         completion: completion)
        }
    }
    
    static func delete(addressId: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        PINEncryptor.encrypt(pin: pin, onFailure: completion) { (encryptedPin) in
            self.request(method: .post,
                         path: Path.delete(addressId: addressId),
                         parameters: ["PIN": encryptedPin],
                         completion: completion)
        }
    }
    
}
