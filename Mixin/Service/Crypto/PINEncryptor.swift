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
            let results = encrypt(pin: pin)
            DispatchQueue.main.async {
                switch results {
                case .success(let encrypted):
                    onSuccess(encrypted)
                case .failure(let error):
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
        var time = UInt64(Date().timeIntervalSince1970).littleEndian
        let timeData = Data(bytes: &time, count: MemoryLayout<UInt64>.size)
        let iterator = AppGroupUserDefaults.Crypto.iterator
        AppGroupUserDefaults.Crypto.iterator = iterator + 1
        let iteratorData = withUnsafeBytes(of: iterator.littleEndian) { buffer in
            Data(bytes: buffer.baseAddress!, count: buffer.count)
        }
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
