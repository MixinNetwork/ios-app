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
        case noAccount
        case evmMismatched
        case solanaMismatched
    }
    
    enum ClassicWalletDerivation {
        
        static func evmPath(index: Int) throws -> DerivationPath {
            try DerivationPath(string: "m/44'/60'/0'/0/\(index)")
        }
        
        static func evmPathRegex() throws -> NSRegularExpression {
            try NSRegularExpression(pattern: #"^m\/44'\/60'\/0'\/0\/(\d+)$"#, options: [])
        }
        
        static func solanaPath(index: Int) throws -> DerivationPath {
            try DerivationPath(string: "m/44'/501'/\(index)'/0'")
        }
        
        static func solanaPathRegex() throws -> NSRegularExpression {
            try NSRegularExpression(pattern: #"^m\/44'\/501'\/(\d+)'\/0'$"#, options: [])
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
    ) async throws -> [CreateSigningWalletRequest.SignedAddress] {
        guard let userID = LoginManager.shared.account?.userID else {
            throw GenerationError.noAccount
        }
        let spendKey = try await TIP.spendPriv(pin: pin)
        let hexSpendKey = spendKey.hexEncodedString()
        
        let evmAddress = try {
            let path = try ClassicWalletDerivation.evmPath(index: index)
            let account = try {
                let priv = try TIP.deriveEthereumPrivateKey(spendKey: spendKey, path: path)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                return try EthereumAccount(keyStorage: keyStorage)
            }()
            let destination = account.address.toChecksumAddress()
            let validationDestination = try {
                var error: NSError?
                let address = BlockchainGenerateEthereumAddress(hexSpendKey, path.string, &error)
                if let error {
                    throw error
                }
                return address
            }()
            guard destination == validationDestination else {
                Logger.web3.error(category: "TIP+Web3", message: "Derive EVM Address: \(destination), \(validationDestination)")
                throw GenerationError.evmMismatched
            }
            return try CreateSigningWalletRequest.SignedAddress(
                destination: destination,
                chainID: ChainID.ethereum,
                path: path.string,
                userID: userID
            ) { message in
                try account.signMessage(message: message)
            }
        }()
        
        let solanaAddress = try {
            let path = try ClassicWalletDerivation.solanaPath(index: index)
            let privateKey = try TIP.deriveSolanaPrivateKey(spendKey: spendKey, path: path)
            let destination = try Solana.publicKey(seed: privateKey)
            let validationDestination = try {
                var error: NSError?
                let address = BlockchainGenerateSolanaAddress(hexSpendKey, path.string, &error)
                if let error {
                    throw error
                }
                return address
            }()
            guard destination == validationDestination else {
                Logger.web3.error(category: "TIP+Web3", message: "Derive Solana Address: \(destination), \(validationDestination)")
                throw GenerationError.solanaMismatched
            }
            return try CreateSigningWalletRequest.SignedAddress(
                destination: destination,
                chainID: ChainID.solana,
                path: path.string,
                userID: userID
            ) { message in
                try Solana.sign(
                    message: message,
                    withPrivateKeyFrom: privateKey,
                    format: .hex
                )
            }
        }()
        
        return [evmAddress, solanaAddress]
    }
    
    static func registerDefaultCommonWalletIfNeeded(pin: String) async throws {
        let remoteWallets = try await RouteAPI.wallets()
        Web3WalletDAO.shared.save(
            wallets: remoteWallets.map(\.wallet),
            addresses: remoteWallets.flatMap(\.addresses)
        )
        if remoteWallets.contains(where: { $0.wallet.category.knownCase == .classic }) {
            // Already registered
            Logger.login.info(category: "TIP+Web3", message: "Skip classic wallet register")
            return
        }
        
        Logger.login.info(category: "TIP+Web3", message: "Register default commmon wallet")
        let addresses = try await deriveAddresses(pin: pin, index: 0)
        let request = CreateSigningWalletRequest(
            name: R.string.localizable.common_wallet(),
            category: .classic,
            addresses: addresses
        )
        let defaultWallet = try await RouteAPI.createWallet(request)
        Web3WalletDAO.shared.save(
            wallets: [defaultWallet.wallet],
            addresses: defaultWallet.addresses
        )
        Logger.login.info(category: "TIP+Web3", message: "Registered")
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
