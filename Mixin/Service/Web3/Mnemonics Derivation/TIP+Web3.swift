import Foundation
import CryptoKit
import web3
import MixinServices
import TIP

// ExtendedKey dependes on secp256k1 which is brought by web3 with SPM
// TODO: Move this extension back to TIP.swift after dependencies are managed with SPM
// MARK: - Common Wallet
extension TIP {
    
    enum GenerationError: Swift.Error {
        case evmMismatched
        case solanaMismatched
    }
    
    private enum CommonWalletDerivationPath {
        static let evm = try! DerivationPath(string: "m/44'/60'/0'/0/0")
        static let solana = try! DerivationPath(string: "m/44'/501'/0'/0'")
    }
    
    static func deriveEthereumPrivateKey(pin: String) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        return try deriveEthereumPrivateKey(spendKey: spendKey)
    }
    
    static func deriveSolanaPrivateKey(pin: String) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        return try deriveSolanaPrivateKey(spendKey: spendKey)
    }
    
    static func registerClassicWalletIfNeeded(pin: String) async throws {
        let remoteWallets = try await RouteAPI.wallets()
        Web3WalletDAO.shared.save(
            wallets: remoteWallets.map(\.wallet),
            addresses: remoteWallets.flatMap(\.addresses)
        )
        if remoteWallets.contains(where: { $0.wallet.category.knownCase == .classic }) {
            // Already registered
            Logger.web3.info(category: "TIP+Web3", message: "Skip classic wallet register")
            return
        }
        
        let spendKey = try await TIP.spendPriv(pin: pin)
        let hexSpendKey = spendKey.hexEncodedString()
        
        let evmAddress = try {
            let priv = try TIP.deriveEthereumPrivateKey(spendKey: spendKey)
            let keyStorage = InPlaceKeyStorage(raw: priv)
            let account = try EthereumAccount(keyStorage: keyStorage)
            return account.address.toChecksumAddress()
        }()
        let redundantEVMAddress = try {
            var error: NSError?
            let address = BlockchainGenerateEthereumAddress(hexSpendKey, &error)
            if let error {
                throw error
            }
            return address
        }()
        guard evmAddress == redundantEVMAddress else {
            Logger.web3.error(category: "TIP+Web3", message: "Derive EVM Address: \(evmAddress), RA: \(redundantEVMAddress)")
            throw GenerationError.evmMismatched
        }
        
        let solanaAddress = try {
            let privateKey = try TIP.deriveSolanaPrivateKey(spendKey: spendKey)
            return try Solana.publicKey(seed: privateKey)
        }()
        let redundantSolanaAddress = try {
            var error: NSError?
            let address = BlockchainGenerateSolanaAddress(hexSpendKey, &error)
            if let error {
                throw error
            }
            return address
        }()
        guard solanaAddress == redundantSolanaAddress else {
            Logger.web3.error(category: "TIP+Web3", message: "Derive Solana Address: \(solanaAddress), RA: \(redundantSolanaAddress)")
            throw GenerationError.solanaMismatched
        }
        
        let request = RouteAPI.WalletRequest(
            name: "Classic Wallet",
            category: .classic,
            addresses: [
                .init(
                    destination: evmAddress,
                    chainID: ChainID.ethereum,
                    path: CommonWalletDerivationPath.evm.string,
                ),
                .init(
                    destination: solanaAddress,
                    chainID: ChainID.solana,
                    path: CommonWalletDerivationPath.solana.string
                ),
            ]
        )
        let commonWallet = try await RouteAPI.createWallet(request)
        Web3WalletDAO.shared.save(
            wallets: [commonWallet.wallet],
            addresses: commonWallet.addresses
        )
    }
    
    private static func deriveEthereumPrivateKey(spendKey: Data) throws -> Data {
        let masterKey = ExtendedKey(seed: spendKey, curve: .secp256k1)
        let derivation = try masterKey.deriveUsingSecp256k1(path: CommonWalletDerivationPath.evm)
        return derivation.key
    }
    
    private static func deriveSolanaPrivateKey(spendKey: Data) throws -> Data {
        let masterKey = ExtendedKey(seed: spendKey, curve: .secp256k1)
        let derivation = try masterKey.deriveUsingSecp256k1(path: CommonWalletDerivationPath.solana)
        return derivation.key
    }
    
}

// MARK: - Imported Mnemonics
extension TIP {
    
    static func importedMnemonicsEncryptionKey(pin: String) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        let key = SHA256.hash(data: spendKey)
        return Data(key)
    }
    
}
