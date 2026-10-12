import Foundation
import CommonCrypto

public enum PBKDF2 {
    
    public enum PseudoRandomAlgorithm {
        case hmacSHA512
    }
    
    public enum DerivationError: Error {
        case code(Int32)
    }
    
    public static func derivation(
        password: String,
        salt: String,
        pseudoRandomAlgorithm: PseudoRandomAlgorithm,
        iterationCount rounds: UInt32,
        keyCount: Int
    ) throws -> Data {
        let passwordData = Data(
            password.decomposedStringWithCompatibilityMapping.utf8
        )
        let saltData = Data(
            salt.decomposedStringWithCompatibilityMapping.utf8
        )
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
            throw DerivationError.code(status)
        }
    }
    
}
