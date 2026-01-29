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
        case bitcoinMismatched
        case evmMismatched
        case solanaMismatched
    }
    
    static func deriveBitcoinPrivateKey(
        pin: String,
        path: DerivationPath
    ) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        return try deriveBitcoinPrivateKey(spendKey: spendKey, path: path)
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
        
        let bitcoinAddress = try {
            let path = try DerivationPath.bitcoin(index: index)
            let privateKey = try TIP.deriveBitcoinPrivateKey(spendKey: spendKey, path: path)
            let destination = try Bitcoin.segwitAddress(privateKey: privateKey)
            let validationDestination = try {
                var error: NSError?
                let address = BlockchainGenerateBitcoinSegwitAddress(hexSpendKey, path.string, &error)
                if let error {
                    throw error
                }
                return address
            }()
            guard destination == validationDestination else {
                Logger.web3.error(category: "TIP+Web3", message: "Derive Bitcoin Address: \(destination), \(validationDestination)")
                throw GenerationError.bitcoinMismatched
            }
            return try CreateSigningWalletRequest.SignedAddress(
                destination: destination,
                chainID: ChainID.bitcoin,
                path: path.string,
                userID: userID
            ) { message in
                try Bitcoin.sign(message: message, with: privateKey)
            }
        }()
        
        let evmAddress = try {
            let path = try DerivationPath.evm(index: index)
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
            let path = try DerivationPath.solana(index: index)
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
        
        return [bitcoinAddress, evmAddress, solanaAddress]
    }
    
    static func registerDefaultCommonWalletIfNeeded(pin: String) async throws {
        let remoteWallets = try await RouteAPI.wallets()
        Web3WalletDAO.shared.save(
            wallets: remoteWallets.map(\.wallet),
            addresses: remoteWallets.flatMap(\.addresses)
        )
        let hasCommonWalletRegistered = remoteWallets.contains { response in
            response.wallet.category.knownCase == .classic
        }
        let hasBitcoinAddressUpdated = remoteWallets.allSatisfy { response in
            switch response.bitcoinAvailability {
            case .available, .notInvolved:
                true
            case .unavailable:
                false
            }
        }
        if hasCommonWalletRegistered {
            if hasBitcoinAddressUpdated {
                Logger.login.info(category: "TIP+Web3", message: "All common wallets set up")
            } else {
                Logger.login.info(category: "TIP+Web3", message: "Update Bitcoin address")
                struct BitcoinUpdate {
                    let walletID: String
                    let address: CreateSigningWalletRequest.SignedAddress
                }
                var updates: [BitcoinUpdate] = []
                for response in remoteWallets {
                    let hasBitcoinAddress = response.addresses.contains { address in
                        address.chainID == ChainID.bitcoin
                    }
                    if hasBitcoinAddress {
                        continue
                    }
                    
                    let wallet = response.wallet
                    let paths = response.addresses.compactMap(\.path)
                    let index = try SequentialWalletPathGenerator.maxIndex(paths: paths)
                    let path = try DerivationPath.bitcoin(index: index)
                    
                    let privateKey: Data
                    let destination: String
                    switch wallet.category.knownCase {
                    case .classic:
                        privateKey = try await deriveBitcoinPrivateKey(pin: pin, path: path)
                        destination = try Bitcoin.segwitAddress(privateKey: privateKey)
                        let validationDestination = try await {
                            let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
                            var error: NSError?
                            let address = BlockchainGenerateBitcoinSegwitAddress(spendKey, path.string, &error)
                            if let error {
                                throw error
                            }
                            return address
                        }()
                        guard destination == validationDestination else {
                            Logger.web3.error(category: "TIP+Web3", message: "Update Bitcoin Address: \(destination), \(validationDestination)")
                            throw GenerationError.bitcoinMismatched
                        }
                    case .importedMnemonic:
                        let encryptedMnemonics = AppGroupKeychain.importedMnemonics(
                            walletID: wallet.walletID
                        )
                        if let encryptedMnemonics {
                            let key = try await TIP.importedWalletEncryptionKey(pin: pin)
                            let mnemonics = try encryptedMnemonics.decrypt(with: key)
                            let derivation = try mnemonics.checkedDerivationForBitcoin(path: path)
                            privateKey = derivation.privateKey
                            destination = derivation.address
                        } else {
                            // Skipped. Could be updated when re-importing the mnemonics
                            continue
                        }
                    case .importedPrivateKey, .watchAddress, .none:
                        continue
                    }
                    
                    let address = try CreateSigningWalletRequest.SignedAddress(
                        destination: destination,
                        chainID: ChainID.bitcoin,
                        path: path.string,
                        userID: myUserId
                    ) { message in
                        try Bitcoin.sign(message: message, with: privateKey)
                    }
                    let update = BitcoinUpdate(walletID: wallet.walletID, address: address)
                    updates.append(update)
                }
                Logger.login.info(category: "TIP+Web3", message: "Update Bitcoin for: \(updates.map(\.walletID))")
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for update in updates {
                        group.addTask {
                            let addresses = try await RouteAPI.updateWallet(
                                id: update.walletID,
                                appendingAddresses: [update.address]
                            )
                            Web3AddressDAO.shared.save(addresses: addresses)
                            Logger.login.info(category: "TIP+Web3", message: "\(update.walletID) bitcoin updated")
                        }
                    }
                    try await group.waitForAll()
                }
            }
        } else {
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
    }
    
    private static func deriveBitcoinPrivateKey(
        spendKey: Data,
        path: DerivationPath
    ) throws -> Data {
        let masterKey = ExtendedKey(seed: spendKey, curve: .secp256k1)
        let derivation = try masterKey.deriveUsingSecp256k1(path: path)
        return derivation.key
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
