import Foundation
import CryptoKit
import Clibsodium

public class Ed25519PublicKey {
    
    public let rawRepresentation: Data
    public let x25519Representation: Data
    
    private let key: Curve25519.Signing.PublicKey
    
    init?(key: Curve25519.Signing.PublicKey) {
        let rawRepresentation = key.rawRepresentation
        guard let x25519 = Self.x25519(from: rawRepresentation) else {
            return nil
        }
        self.rawRepresentation = rawRepresentation
        self.x25519Representation = x25519
        self.key = key
    }
    
    private static func x25519(from ed25519: Data) -> Data? {
        let count = Int(crypto_scalarmult_curve25519_BYTES)
        let buffer = malloc(count)!.assumingMemoryBound(to: UInt8.self)
        let success: Bool = ed25519.withUnsafeBytes { ed25519 in
            let e = ed25519.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return crypto_sign_ed25519_pk_to_curve25519(buffer, e) == 0
        }
        if success {
            return Data(bytesNoCopy: buffer, count: count, deallocator: .free)
        } else {
            free(buffer)
            return nil
        }
    }
    
}
