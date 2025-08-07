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
    
    enum CommonWalletDerivation {
        
        static func evmPath(index: Int) throws -> DerivationPath {
            try DerivationPath(string: "m/44'/60'/0'/0/\(index)")
        }
        
        static func solanaPath(index: Int) throws -> DerivationPath {
            try DerivationPath(string: "m/44'/501'/\(index)'/0'")
        }
        
    }
    
    static func deriveEthereumPrivateKey(
        pin: String,
        path: DerivationPath
    ) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        return try deriveEthereumPrivateKey(spendKey: spendKey, path: path)
    }
    
    static func deriveSolanaPrivateKey(
        pin: String,
        path: DerivationPath
    ) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        return try deriveSolanaPrivateKey(spendKey: spendKey, path: path)
    }
    
    static func deriveAddresses(
        pin: String,
        index: Int
    ) async throws -> [CreateWalletRequest.Address] {
        let spendKey = try await TIP.spendPriv(pin: pin)
        let hexSpendKey = spendKey.hexEncodedString()
        
        let evmPath = try CommonWalletDerivation.evmPath(index: index)
        let evmAddress = try {
            let priv = try TIP.deriveEthereumPrivateKey(spendKey: spendKey, path: evmPath)
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
        
        let solanaPath = try CommonWalletDerivation.solanaPath(index: index)
        let solanaAddress = try {
            let privateKey = try TIP.deriveSolanaPrivateKey(spendKey: spendKey, path: solanaPath)
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
        
        return [
            CreateWalletRequest.Address(
                destination: evmAddress,
                chainID: ChainID.ethereum,
                path: evmPath.string
            ),
            CreateWalletRequest.Address(
                destination: solanaAddress,
                chainID: ChainID.solana,
                path: solanaPath.string
            ),
        ]
    }
    
    static func registerDefaultCommonWalletIfNeeded(pin: String) async throws {
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
        
        let addresses = try await deriveAddresses(pin: pin, index: 0)
        let request = CreateWalletRequest(
            name: "Classic Wallet",
            category: .classic,
            addresses: addresses
        )
        let commonWallet = try await RouteAPI.createWallet(request)
        Web3WalletDAO.shared.save(
            wallets: [commonWallet.wallet],
            addresses: commonWallet.addresses
        )
    }
    
    private static func deriveEthereumPrivateKey(
        spendKey: Data,
        path: DerivationPath
    ) throws -> Data {
        let masterKey = ExtendedKey(seed: spendKey, curve: .secp256k1)
        let derivation = try masterKey.deriveUsingSecp256k1(path: path)
        return derivation.key
    }
    
    private static func deriveSolanaPrivateKey(
        spendKey: Data,
        path: DerivationPath
    ) throws -> Data {
        let masterKey = ExtendedKey(seed: spendKey, curve: .secp256k1)
        let derivation = try masterKey.deriveUsingSecp256k1(path: path)
        return derivation.key
    }
    
}

// MARK: - Imported Wallets
extension TIP {
    
    static func importedWalletEncryptionKey(pin: String) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        let key = SHA256.hash(data: spendKey)
        return Data(key)
    }
    
}
