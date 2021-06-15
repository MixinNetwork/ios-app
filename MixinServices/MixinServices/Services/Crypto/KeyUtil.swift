import Foundation
import CommonCrypto
import Security
import UIKit

public enum KeyUtil {
    
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
    
}
