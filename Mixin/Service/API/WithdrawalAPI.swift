import Alamofire
import MixinServices

final class WithdrawalAPI: MixinAPI {
    
    static let shared = WithdrawalAPI()
    
    private enum url {
        static func addresses(assetId: String) -> String {
            return "assets/\(assetId)/addresses"
        }
        
        static let addresses = "addresses"
        static func address(addressId: String) -> String {
            return "addresses/\(addressId)"
        }
        
        static let withdrawals = "withdrawals"
        static func delete(addressId: String) -> String {
            return "addresses/\(addressId)/delete"
        }
    }
    
    func address(addressId: String) -> MixinAPI.Result<Address> {
        return request(method: .get, url: url.address(addressId: addressId))
    }
    
    func address(addressId: String, completion: @escaping (MixinAPI.Result<Address>) -> Void) {
        request(method: .get, url: url.address(addressId: addressId), completion: completion)
    }
    
    func addresses(assetId: String, completion: @escaping (MixinAPI.Result<[Address]>) -> Void) {
        request(method: .get, url: url.addresses(assetId: assetId), completion: completion)
    }
    
    func save(address: AddressRequest, completion: @escaping (MixinAPI.Result<Address>) -> Void) {
        KeyUtil.aesEncrypt(pin: address.pin, completion: completion) { [weak self](encryptedPin) in
            var address = address
            address.pin = encryptedPin
            self?.request(method: .post, url: url.addresses, parameters: address.toParameters(), encoding: EncodableParameterEncoding<AddressRequest>(), completion: completion)
        }
    }
    
    func withdrawal(withdrawal: WithdrawalRequest, completion: @escaping (MixinAPI.Result<Snapshot>) -> Void) {
        KeyUtil.aesEncrypt(pin: withdrawal.pin, completion: completion) { [weak self](encryptedPin) in
            var withdrawal = withdrawal
            withdrawal.pin = encryptedPin
            self?.request(method: .post, url: url.withdrawals, parameters: withdrawal.toParameters(), encoding: EncodableParameterEncoding<WithdrawalRequest>(), completion: completion)
        }
    }
    
    func delete(addressId: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            self?.request(method: .post, url: url.delete(addressId: addressId), parameters: ["PIN": encryptedPin], completion: completion)
        }
    }
    
}
