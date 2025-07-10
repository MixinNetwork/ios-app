import Foundation
import CryptoKit
import web3
import MixinServices
import TIP

// ExtendedKey dependes on secp256k1 which is brought by web3 with SPM
// TODO: Move this extension back to TIP.swift after dependencies are managed with SPM
extension TIP {
    
    enum GenerationError: Swift.Error {
        case evmMismatched
        case solanaMismatched
    }
    
    static func deriveEthereumPrivateKey(pin: String) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        return try deriveEthereumPrivateKey(spendKey: spendKey)
    }
    
    static func deriveEthereumPrivateKey(spendKey: Data) throws -> Data {
        let derived = try ExtendedKey(seed: spendKey, curve: .secp256k1)
            .privateKeyUsingSecp256k1(index: .hardened(44))
            .privateKeyUsingSecp256k1(index: .hardened(60))
            .privateKeyUsingSecp256k1(index: .hardened(0))
            .privateKeyUsingSecp256k1(index: .normal(0))
            .privateKeyUsingSecp256k1(index: .normal(0))
        return derived.key
    }
    
    static func deriveSolanaPrivateKey(pin: String) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        return try deriveSolanaPrivateKey(spendKey: spendKey)
    }
    
    static func deriveSolanaPrivateKey(spendKey: Data) throws -> Data {
        let derived = try ExtendedKey(seed: spendKey, curve: .secp256k1)
            .privateKeyUsingSecp256k1(index: .hardened(44))
            .privateKeyUsingSecp256k1(index: .hardened(501))
            .privateKeyUsingSecp256k1(index: .hardened(0))
            .privateKeyUsingSecp256k1(index: .hardened(0))
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
    
    static func importedWalletSpendKey(pin: String) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        let key = SHA256.hash(data: spendKey)
        return Data(key)
    }
    
    static func registerClassicWallet(pin: String) async throws {
        let spendKey = try await TIP.spendPriv(pin: pin)
        
        let evmAddress = try {
            let priv = try TIP.deriveEthereumPrivateKey(spendKey: spendKey)
            let keyStorage = InPlaceKeyStorage(raw: priv)
            let account = try EthereumAccount(keyStorage: keyStorage)
            return account.address.toChecksumAddress()
        }()
        let redundantEVMAddress = try TIP.evmAddress(spendKey: spendKey)
        guard evmAddress == redundantEVMAddress else {
            Logger.web3.error(category: "TIP+Web3", message: "Derive EVM Address: \(evmAddress), RA: \(redundantEVMAddress)")
            throw GenerationError.evmMismatched
        }
        
        let solanaAddress = try {
            let privateKey = try TIP.deriveSolanaPrivateKey(spendKey: spendKey)
            return try Solana.publicKey(seed: privateKey)
        }()
        let redundantSolanaAddress = try TIP.solanaAddress(spendKey: spendKey)
        guard solanaAddress == redundantSolanaAddress else {
            Logger.web3.error(category: "TIP+Web3", message: "Derive Solana Address: \(solanaAddress), RA: \(redundantSolanaAddress)")
            throw GenerationError.solanaMismatched
        }
        
        let remoteWallets = try await RouteAPI.wallets()
        let request = RouteAPI.WalletRequest(name: "Classic Wallet", category: .classic, addresses: [
            .init(destination: evmAddress, chainID: ChainID.ethereum),
            .init(destination: solanaAddress, chainID: ChainID.solana),
        ])
        let classicWallet = try await RouteAPI.createWallet(request)
        Web3WalletDAO.shared.save(wallets: remoteWallets.map(\.wallet))
        Web3AddressDAO.shared.save(addresses: remoteWallets.flatMap(\.addresses))
        Web3WalletDAO.shared.save(wallets: [classicWallet.wallet])
        Web3AddressDAO.shared.save(addresses: classicWallet.addresses)
    }
    
}
