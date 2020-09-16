import Foundation
import CommonCrypto
import MixinServices

enum PINEncryptor {
    
    enum Error: Swift.Error {
        case invalidPIN
        case missingPINToken
        case generateSecuredRandom
        case aesEncryption(code: Int32)
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
        guard let iv = Data(withSecuredRandomBytesOfCount: kCCBlockSizeAES128) else {
            return .failure(.generateSecuredRandom)
        }
        var time = UInt64(Date().timeIntervalSince1970).littleEndian
        let timeData = Data(bytes: &time, count: MemoryLayout<UInt64>.size)
        var iterator = AppGroupUserDefaults.Crypto.iterator.littleEndian
        AppGroupUserDefaults.Crypto.iterator += 1
        let iteratorData = Data(bytes: &iterator, count: MemoryLayout<UInt64>.size)
        let plain = pinData + timeData + iteratorData
        let key = pinToken as NSData
        let dataIn = plain as NSData
        var dataOut = [UInt8](repeating: 0, count: kCCBlockSizeAES128 + timeData.count + iteratorData.count)
        var dataOutMoved = 0
        let status = CCCrypt(CCOperation(kCCEncrypt),
                             CCAlgorithm(kCCAlgorithmAES),
                             CCOptions(kCCOptionPKCS7Padding),
                             key.bytes,
                             key.length,
                             (iv as NSData).bytes,
                             dataIn.bytes,
                             dataIn.length,
                             &dataOut,
                             dataOut.count,
                             &dataOutMoved)
        guard status == kCCSuccess else {
            return .failure(.aesEncryption(code: status))
        }
        let cipher = Data(iv + dataOut.prefix(dataOutMoved))
        let base64Encoded = cipher.base64EncodedString()
        return .success(base64Encoded)
    }
    
}
