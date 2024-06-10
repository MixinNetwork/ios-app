import Foundation
import MixinServices
import TIP

// ExtendedKey dependes on secp256k1 which is brought by web3 with SPM
// TODO: Move this extension back to TIP.swift after dependencies are managed with SPM
extension TIP {
    
    static func deriveEthereumPrivateKey(pin: String) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        return try deriveEthereumPrivateKey(spendKey: spendKey)
    }
    
    static func deriveEthereumPrivateKey(spendKey: Data) throws -> Data {
        let derived = try ExtendedKey(seed: spendKey)
            .privateKey(index: .hardened(44))
            .privateKey(index: .hardened(60))
            .privateKey(index: .hardened(0))
            .privateKey(index: .normal(0))
            .privateKey(index: .normal(0))
        return derived.key
    }
    
    static func deriveSolanaPrivateKey(pin: String) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        return try deriveSolanaPrivateKey(spendKey: spendKey)
    }
    
    static func deriveSolanaPrivateKey(spendKey: Data) throws -> Data {
        let derived = try ExtendedKey(seed: spendKey)
            .privateKey(index: .hardened(44))
            .privateKey(index: .hardened(501))
            .privateKey(index: .hardened(0))
            .privateKey(index: .hardened(0))
        return derived.key
    }
    
    static func evmAddress(spendKey: Data) throws -> String {
        let seed = spendKey.hexEncodedString()
        var error: NSError?
        let address = BlockchainGenerateEthereumAddress(seed, &error)
        if let error {
            throw error as Swift.Error
        }
        return address
    }
    
    static func solanaAddress(spendKey: Data) throws -> String {
        let seed = spendKey.hexEncodedString()
        var error: NSError?
        let address = BlockchainGenerateSolanaAddress(seed, &error)
        if let error {
            throw error as Swift.Error
        }
        return address
    }
    
}
