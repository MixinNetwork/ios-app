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
    
    static func encrypt<Response>(pin: String, onFailure: @escaping (MixinAPI.Result<Response>) -> Void, onSuccess: @escaping (String) -> Void) {
        switch encrypt(pin: pin) {
        case .success(let encrypted):
            onSuccess(encrypted)
        case .failure(let error):
            onFailure(.failure(.pinEncryption(error)))
        }
    }
    
    static func encrypt(pin: String) -> Result<String, Error> {
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
        var time = UInt64(Date().timeIntervalSince1970).littleEndian
        let timeData = Data(bytes: &time, count: MemoryLayout<UInt64>.size)
        var iterator = AppGroupUserDefaults.Crypto.iterator.littleEndian
        AppGroupUserDefaults.Crypto.iterator += 1
        let iteratorData = Data(bytes: &iterator, count: MemoryLayout<UInt64>.size)
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
