import Foundation
import MixinServices

// ExtendedKey dependes on secp256k1 which is brought by web3 with SPM
// TODO: Move this extension back to TIP.swift after dependencies are managed with SPM
extension TIP {
    
    static func ethereumPrivateKey(pin: String) async throws -> Data {
        let priv = try await getOrRecoverTIPPriv(pin: pin)
        let derived = try ExtendedKey(seed: priv)
            .privateKey(index: .hardened(44))
            .privateKey(index: .hardened(60))
            .privateKey(index: .hardened(0))
            .privateKey(index: .normal(0))
            .privateKey(index: .normal(0))
        return derived.key
    }
    
}
