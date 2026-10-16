import Foundation
import CryptoKit
import TIP

public class Ed25519PrivateKey {
    
    public let rawRepresentation: Data
    public let x25519Representation: Data
    public let publicKey: Ed25519PublicKey
    
    private let key: Curve25519.Signing.PrivateKey
    
    public convenience init() throws {
        var error: NSError?
        var key = Curve25519.Signing.PrivateKey()
        var goImpl = Ed25519NewKeyFromSeed(key.rawRepresentation, &error)
        while goImpl == nil || error != nil {
            key = Curve25519.Signing.PrivateKey()
            goImpl = Ed25519NewKeyFromSeed(key.rawRepresentation, &error)
        }
        try self.init(key: key)
    }
    
    public convenience init(rawRepresentation: Data) throws {
        var error: NSError?
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: rawRepresentation)
        let goImpl = Ed25519NewKeyFromSeed(key.rawRepresentation, &error)
        guard goImpl != nil && error == nil else {
            throw ValidationError.invalidSeed(error)
        }
        try self.init(key: key)
    }
    
    init(key: Curve25519.Signing.PrivateKey) throws {
        let rawRepresentation = key.rawRepresentation
        let x25519Representation = Self.x25519(from: rawRepresentation)
        let agreementKey = try Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: x25519Representation,
        )
        self.rawRepresentation = rawRepresentation
        self.x25519Representation = x25519Representation
        self.publicKey = Ed25519PublicKey(
            key: key.publicKey,
            agreementKey: agreementKey.publicKey,
        )
        self.key = key
    }
    
    public func signature(for data: Data) throws -> Data {
        try key.signature(for: data)
    }
    
}

extension Ed25519PrivateKey {
    
    enum ValidationError: Error {
        case invalidSeed(NSError?)
    }
    
    private static func x25519(from ed25519: Data) -> Data {
        let hash = SHA512.hash(data: ed25519)
        var x25519 = Data(hash)
        x25519[0] &= 248;
        x25519[31] &= 127;
        x25519[31] |= 64;
        return x25519.prefix(32)
    }
    
}
