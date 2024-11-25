import Foundation
import CommonCrypto

enum PBKDF2 {
    
    enum PseudoRandomAlgorithm {
        case hmacSHA512
    }
    
    static func derivation(
        password: String,
        salt: String,
        pseudoRandomAlgorithm: PseudoRandomAlgorithm,
        iterationCount rounds: UInt32,
        keyCount: Int
    ) -> Data? {
        guard let passwordData = password.data(using: .utf8) else {
            return nil
        }
        guard let saltData = salt.data(using: .utf8) else {
            return nil
        }
        let prf = switch pseudoRandomAlgorithm {
        case .hmacSHA512:
            CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512)
        }
        var key = Data(count: keyCount)
        let status = passwordData.withUnsafeBytes { password in
            saltData.withUnsafeBytes { salt in
                key.withUnsafeMutableBytes { key in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        password.baseAddress,
                        password.count,
                        salt.baseAddress,
                        salt.count,
                        prf,
                        rounds,
                        key.baseAddress,
                        keyCount
                    )
                }
            }
        }
        if status == kCCSuccess {
            return key
        } else {
            return nil
        }
    }
    
}
