import Alamofire
import MixinServices

public final class WithdrawalAPI: MixinAPI {
    
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
    
    public static func address(addressId: String) -> MixinAPI.Result<Address> {
        return request(method: .get, path: Path.address(addressId: addressId))
    }
    
    public static func address(addressId: String, completion: @escaping (MixinAPI.Result<Address>) -> Void) {
        request(method: .get, path: Path.address(addressId: addressId), completion: completion)
    }
    
    public static func addresses(assetId: String, completion: @escaping (MixinAPI.Result<[Address]>) -> Void) {
        request(method: .get, path: Path.addresses(assetId: assetId), completion: completion)
    }
    
    public static func save(address: AddressRequest, completion: @escaping (MixinAPI.Result<Address>) -> Void) {
        PINEncryptor.encrypt(pin: address.pin, tipBody: {
            try TIPBody.addAddres(assetID: address.assetId, publicKey: address.destination, keyTag: address.tag, name: address.label)
        }, onFailure: completion) { (encryptedPin) in
            var address = address
            address.pin = encryptedPin
            self.request(method: .post,
                         path: Path.addresses,
                         parameters: address,
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
    public static func withdrawal(withdrawal: WithdrawalRequest, completion: @escaping (MixinAPI.Result<Snapshot>) -> Void) {
        PINEncryptor.encrypt(pin: withdrawal.pin, tipBody: {
            try TIPBody.createWithdrawal(addressID: withdrawal.addressId, amount: withdrawal.amount, fee: withdrawal.fee, traceID: withdrawal.traceId, memo: withdrawal.memo)
        }, onFailure: completion) { (encryptedPin) in
            var withdrawal = withdrawal
            withdrawal.pin = encryptedPin
            self.request(method: .post,
                         path: Path.withdrawals,
                         parameters: withdrawal,
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
    public static func externalWithdrawal(addressId: String, withdrawal: WithdrawalRequest, completion: @escaping (MixinAPI.Result<Snapshot>) -> Void) {
        PINEncryptor.encrypt(pin: withdrawal.pin, tipBody: {
            try TIPBody.createWithdrawal(addressID: addressId, amount: withdrawal.amount, fee: withdrawal.fee, traceID: withdrawal.traceId, memo: withdrawal.memo)
        }, onFailure: completion) { (encryptedPin) in
            var withdrawal = withdrawal
            withdrawal.pin = encryptedPin
            self.request(method: .post,
                         path: Path.withdrawals,
                         parameters: withdrawal,
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
    public static func delete(addressId: String, pin: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        PINEncryptor.encrypt(pin: pin, tipBody: {
            try TIPBody.removeAddress(addressID: addressId)
        }, onFailure: completion) { (encryptedPin) in
            self.request(method: .post,
                         path: Path.delete(addressId: addressId),
                         parameters: ["pin_base64": encryptedPin],
                         options: .disableRetryOnRequestSigningTimeout,
                         completion: completion)
        }
    }
    
}
