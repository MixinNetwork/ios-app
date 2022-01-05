import Foundation
import libsignal_protocol_c

public enum AgreementCalculator {
    
    public static func agreement(publicKey: Data, privateKey: Data) -> Data? {
        let keyLength = Int(DJB_KEY_LEN)
        guard publicKey.count == keyLength && privateKey.count == keyLength else {
            return nil
        }
        guard let agreement = malloc(keyLength)?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }
        let status = publicKey.withUnsafeBytes { publicKey in
            privateKey.withUnsafeBytes { privateKey in
                curve25519_donna(agreement, privateKey, publicKey)
            }
        }
        if status == 0 {
            return Data(bytesNoCopy: agreement, count: keyLength, deallocator: .free)
        } else {
            free(agreement)
            return nil
        }
    }
    
}
