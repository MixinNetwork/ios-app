import Foundation
import CommonCrypto
import MixinServices

enum PINEncryptor {
    
    enum Error: Swift.Error {
        case invalidPIN
        case missingPINToken
        case ivGeneration
        case encryption(Swift.Error)
    }
    
    private static let queue = DispatchQueue(label: "one.mixin.service.PINEncryptor")

    static func encrypt<Response>(pin: String, onFailure: @escaping (MixinAPI.Result<Response>) -> Void, onSuccess: @escaping (String) -> Void) {
        queue.async {
            switch encrypt(pin: pin) {
            case .success(let encrypted):
                onSuccess(encrypted)
            case .failure(let error):
                DispatchQueue.main.async {
                    onFailure(.failure(.pinEncryption(error)))
                }
            }
        }
    }
    
    private static func encrypt(pin: String) -> Result<String, Error> {
        let pinToken: Data
        if let token = AppGroupKeychain.pinToken {
            pinToken = token
        } else if let encoded = AppGroupUserDefaults.Account.pinToken, let token = Data(base64Encoded: encoded) {
            pinToken = token
        } else {
            return .failure(.missingPINToken)
        }
        guard let pinData = pin.data(using: .utf8) else {
            return .failure(.invalidPIN)
        }
        guard let iv = Data(withNumberOfSecuredRandomBytes: kCCBlockSizeAES128) else {
            return .failure(.ivGeneration)
        }
        
        let time = UInt64(Date().timeIntervalSince1970)
        let timeData = withUnsafeBytes(of: time.littleEndian, { Data($0) })
        
        var iterator: UInt64 = 0
        PropertiesDAO.shared.updateValue(forKey: .iterator, type: UInt64.self) { databaseValue in
            let userDefaultsValue = AppGroupUserDefaults.Crypto.iterator
            if let databaseValue = databaseValue {
                iterator = max(databaseValue, userDefaultsValue)
            } else {
                iterator = userDefaultsValue
                Logger.general.info(category: "PIN", message: "Iterator initialized to \(userDefaultsValue)")
            }
            let nextIterator = iterator + 1
            AppGroupUserDefaults.Crypto.iterator = nextIterator
            return nextIterator
        }
        let iteratorData = withUnsafeBytes(of: iterator.littleEndian, { Data($0) })
        Logger.general.info(category: "PIN", message: "Encrypt with it: \(iterator)")
        
        let plain = pinData + timeData + iteratorData
        do {
            let encrypted = try AESCryptor.encrypt(plain, with: pinToken, iv: iv, padding: .pkcs7)
            let base64Encoded = (iv + encrypted).base64EncodedString()
            return .success(base64Encoded)
        } catch {
            return .failure(.encryption(error))
        }
    }
    
}
