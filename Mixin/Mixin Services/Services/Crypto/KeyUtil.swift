import Foundation
import CommonCrypto
import Security
import UIKit
import Goutils

class KeyUtil {

    static func stripRsaPrivateKeyHeaders(_ pemString: String) -> String {
        let lines = pemString.components(separatedBy: "\n").filter { line in
            return !line.hasPrefix("-----BEGIN") && !line.hasPrefix("-----END")
        }

        guard lines.count != 0 else {
            return pemString
        }

        return lines.joined(separator: "")
    }

    static func secureRandom(blockSize: Int = kCCBlockSizeAES128) -> [UInt8]? {
        var iv = [UInt8](repeating: 0, count: blockSize)
        if SecRandomCopyBytes(kSecRandomDefault, blockSize, &iv) != 0 {
            return nil
        }
        return iv
    }
    
    static func aesEncrypt<ResultType>(pin: String, completion: @escaping (APIResult<ResultType>) -> Void, callback: (String) -> Void) {
        guard let pinToken = AppGroupUserDefaults.Account.pinToken, let encryptedPin = KeyUtil.aesEncrypt(pinToken: pinToken, pin: pin) else {
            completion(.failure(APIError(status: 200, code: 400, description: Localized.TOAST_OPERATION_FAILED)))
            return
        }
        callback(encryptedPin)
    }

    static func aesEncrypt(pinToken: String, pin: String) -> String? {
        guard let key = Data(base64Encoded: pinToken), let data = pin.data(using: .utf8), let iv = secureRandom() else {
            return nil
        }

        var nowInterval = UInt64(Date().timeIntervalSince1970).littleEndian
        let timeData = Data(bytes: &nowInterval, count: MemoryLayout<UInt64>.size)
        var iterator = AppGroupUserDefaults.Crypto.iterator.littleEndian
        let iteratorData = Data(bytes: &iterator, count: MemoryLayout<UInt64>.size)
        AppGroupUserDefaults.Crypto.iterator += 1

        var dataOut = [UInt8](repeating: 0, count: kCCBlockSizeAES128 + timeData.count + iteratorData.count)
        var numBytesEncrypted = 0

        let cryptStatus = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding), key.bytes, key.count, iv, data.bytes + timeData.bytes + iteratorData.bytes, data.count + timeData.count + iteratorData.count, &dataOut, dataOut.count, &numBytesEncrypted)

        guard cryptStatus == CCCryptorStatus(kCCSuccess) else {
            return nil
        }
        return Data(iv + dataOut.prefix(numBytesEncrypted)).base64EncodedString()
    }

    static func rsaDecrypt(pkString: String, sessionId: String, pinToken: String) -> String {
        var error: NSError?
        defer {
            if let err = error  {
                Reporter.report(error: err)
            }
        }
        return GoutilsRsaDecrypt(pinToken, sessionId, pkString, &error)
    }

    static func getPrivateKeyFromPem(pemString: String) -> SecKey? {
        guard let keyData = Data(base64Encoded: stripRsaPrivateKeyHeaders(pemString)) else {
            return nil
        }
        let parameters: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: 1024 ]
        return SecKeyCreateWithData(keyData as CFData, parameters as CFDictionary, nil)
    }
    
    typealias RSAKeyPair = (privateKeyPem: String, publicKey: String)
    static func generateRSAKeyPair(keySize: Int = 1024) -> RSAKeyPair? {
        var publicKey, privateKey: SecKey?
        let pubKeyAttrs: [CFString: Any] = [kSecAttrIsPermanent: NSNumber(value: true), kSecAttrApplicationTag: "one.mixin.messenger.publickey".data(using: .utf8)!]
        let privKeyAttrs: [CFString: Any] = [kSecAttrIsPermanent: NSNumber(value: true), kSecAttrApplicationTag: "one.mixin.messenger.privatekey".data(using: .utf8)!]
        let parameters: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA,
                                     kSecAttrKeySizeInBits: keySize,
                                     kSecPublicKeyAttrs: pubKeyAttrs,
                                     kSecPrivateKeyAttrs: privKeyAttrs]

        let status = SecKeyGeneratePair(parameters as CFDictionary, &publicKey, &privateKey)
        guard status == errSecSuccess, let pubKey = publicKey, let privKey = privateKey else {
            return nil
        }

        guard let pbData = SecKeyCopyExternalRepresentation(pubKey, nil) as Data?,  let prData = SecKeyCopyExternalRepresentation(privKey, nil) as Data? else {
            return nil
        }

        return ("-----BEGIN RSA PRIVATE KEY-----\n\(prData.base64EncodedString())\n-----END RSA PRIVATE KEY-----", pbData.dataByPrependingX509Header().base64EncodedString())
    }
}

fileprivate extension Data {

    func dataByPrependingX509Header() -> Data {
        let result = NSMutableData()

        let encodingLength: Int = (self.count + 1).encodedOctets().count
        let OID: [CUnsignedChar] = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
                                    0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00]

        var builder: [CUnsignedChar] = []

        // ASN.1 SEQUENCE
        builder.append(0x30)

        // Overall size, made of OID + bitstring encoding + actual key
        let size = OID.count + 2 + encodingLength + self.count
        let encodedSize = size.encodedOctets()
        builder.append(contentsOf: encodedSize)
        result.append(builder, length: builder.count)
        result.append(OID, length: OID.count)
        builder.removeAll(keepingCapacity: false)

        builder.append(0x03)
        builder.append(contentsOf: (self.count + 1).encodedOctets())
        builder.append(0x00)
        result.append(builder, length: builder.count)

        // Actual key bytes
        result.append(self)

        return result as Data
    }

}

private extension NSInteger {
    func encodedOctets() -> [CUnsignedChar] {
        // Short form
        if self < 128 {
            return [CUnsignedChar(self)]
        }

        // Long form
        let i = Int(log2(Double(self)) / 8 + 1)
        var len = self
        var result: [CUnsignedChar] = [CUnsignedChar(i + 0x80)]

        for _ in 0..<i {
            result.insert(CUnsignedChar(len & 0xFF), at: 1)
            len = len >> 8
        }

        return result
    }
}
