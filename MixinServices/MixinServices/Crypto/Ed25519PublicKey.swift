import Foundation
import CryptoKit

public class Ed25519PublicKey {
    
    public let rawRepresentation: Data
    public let x25519Representation: Data
    
    private let key: Curve25519.Signing.PublicKey
    
    init(
        key: Curve25519.Signing.PublicKey,
        agreementKey: Curve25519.KeyAgreement.PublicKey,
    ) {
        self.rawRepresentation = key.rawRepresentation
        self.x25519Representation = agreementKey.rawRepresentation
        self.key = key
    }
    
}
