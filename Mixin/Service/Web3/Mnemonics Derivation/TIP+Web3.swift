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
        case pearlMismatched
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
    
    static func derivePearlPrivateKey(
        pin: String,
        path: DerivationPath
    ) async throws -> Data {
        let spendKey = try await TIP.spendPriv(pin: pin)
        return try derivePearlPrivateKey(spendKey: spendKey, path: path)
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
            let crossCheckDestination = try {
                var error: NSError?
                let address = BlockchainGenerateBitcoinSegwitAddress(hexSpendKey, path.string, &error)
                if let error {
                    throw error
                }
                return address
            }()
            guard destination == crossCheckDestination else {
                Logger.web3.error(category: "TIP+Web3", message: "Derive Bitcoin Address: \(destination), \(crossCheckDestination)")
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
        
        let pearlAddress = try {
            let path = try DerivationPath.pearl(index: index)
            let privateKey = try TIP.derivePearlPrivateKey(spendKey: spendKey, path: path)
            let destination = try Pearl.address(privateKey: privateKey)
            let crossCheckDestination = try {
                var error: NSError?
                let address = BlockchainGeneratePearlAddress(hexSpendKey, path.string, &error)
                if let error {
                    throw error
                }
                return address
            }()
            guard destination == crossCheckDestination else {
                Logger.web3.error(category: "TIP+Web3", message: "Derive Pearl Address: \(destination), \(crossCheckDestination)")
                throw GenerationError.pearlMismatched
            }
            return try CreateSigningWalletRequest.SignedAddress(
                destination: destination,
                chainID: ChainID.pearl,
                path: path.string,
                userID: userID
            ) { message in
                try Pearl.sign(message: message, with: privateKey)
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
            let crossCheckDestination = try {
                var error: NSError?
                let address = BlockchainGenerateEthereumAddress(hexSpendKey, path.string, &error)
                if let error {
                    throw error
                }
                return address
            }()
            guard destination == crossCheckDestination else {
                Logger.web3.error(category: "TIP+Web3", message: "Derive EVM Address: \(destination), \(crossCheckDestination)")
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
            let crossCheckDestination = try {
                var error: NSError?
                let address = BlockchainGenerateSolanaAddress(hexSpendKey, path.string, &error)
                if let error {
                    throw error
                }
                return address
            }()
            guard destination == crossCheckDestination else {
                Logger.web3.error(category: "TIP+Web3", message: "Derive Solana Address: \(destination), \(crossCheckDestination)")
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
        
        return [bitcoinAddress, pearlAddress, evmAddress, solanaAddress]
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
        let hasAddressUpdated = remoteWallets.allSatisfy { response in
            let bitcoinAvailable = switch response.bitcoinAvailability {
            case .available, .notInvolved:
                true
            case .unavailable:
                false
            }
            let pearlAvailable = switch response.pearlAvailability {
            case .available, .notInvolved:
                true
            case .unavailable:
                false
            }
            return bitcoinAvailable && pearlAvailable
        }
        if hasCommonWalletRegistered {
            if hasAddressUpdated {
                Logger.login.info(category: "TIP+Web3", message: "All common wallets set up")
            } else {
                Logger.login.info(category: "TIP+Web3", message: "Update wallet addresses")
                struct WalletUpdate {
                    let walletID: String
                    let addresses: [CreateSigningWalletRequest.SignedAddress]
                }
                var updates: [WalletUpdate] = []
                for response in remoteWallets {
                    let hasBitcoinAddress = response.addresses.contains { address in
                        address.chainID == ChainID.bitcoin
                    }
                    let hasPearlAddress = response.addresses.contains { address in
                        address.chainID == ChainID.pearl
                    }
                    if hasBitcoinAddress && hasPearlAddress {
                        continue
                    }
                    
                    let wallet = response.wallet
                    let paths = response.addresses.compactMap(\.path)
                    let index = try SequentialWalletPathGenerator.maxIndex(paths: paths)
                    
                    var newAddresses: [CreateSigningWalletRequest.SignedAddress] = []
                    
                    if !hasBitcoinAddress {
                        let path = try DerivationPath.bitcoin(index: index)
                        let privateKey: Data
                        let destination: String
                        switch wallet.category.knownCase {
                        case .classic:
                            privateKey = try await deriveBitcoinPrivateKey(pin: pin, path: path)
                            destination = try Bitcoin.segwitAddress(privateKey: privateKey)
                            let crossCheckDestination = try await {
                                let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
                                var error: NSError?
                                let address = BlockchainGenerateBitcoinSegwitAddress(spendKey, path.string, &error)
                                if let error {
                                    throw error
                                }
                                return address
                            }()
                            guard destination == crossCheckDestination else {
                                Logger.web3.error(category: "TIP+Web3", message: "Update Bitcoin Address: \(destination), \(crossCheckDestination)")
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
                        newAddresses.append(address)
                    }
                    
                    if !hasPearlAddress {
                        let path = try DerivationPath.pearl(index: index)
                        let privateKey: Data
                        let destination: String
                        switch wallet.category.knownCase {
                        case .classic:
                            privateKey = try await derivePearlPrivateKey(pin: pin, path: path)
                            destination = try Pearl.address(privateKey: privateKey)
                            let crossCheckDestination = try await {
                                let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
                                var error: NSError?
                                let address = BlockchainGeneratePearlAddress(spendKey, path.string, &error)
                                if let error {
                                    throw error
                                }
                                return address
                            }()
                            guard destination == crossCheckDestination else {
                                Logger.web3.error(category: "TIP+Web3", message: "Update Pearl Address: \(destination), \(crossCheckDestination)")
                                throw GenerationError.pearlMismatched
                            }
                        case .importedMnemonic:
                            let encryptedMnemonics = AppGroupKeychain.importedMnemonics(
                                walletID: wallet.walletID
                            )
                            if let encryptedMnemonics {
                                let key = try await TIP.importedWalletEncryptionKey(pin: pin)
                                let mnemonics = try encryptedMnemonics.decrypt(with: key)
                                let derivation = try mnemonics.checkedDerivationForPearl(path: path)
                                privateKey = derivation.privateKey
                                destination = derivation.address
                            } else {
                                continue
                            }
                        case .importedPrivateKey, .watchAddress, .none:
                            continue
                        }
                        
                        let address = try CreateSigningWalletRequest.SignedAddress(
                            destination: destination,
                            chainID: ChainID.pearl,
                            path: path.string,
                            userID: myUserId
                        ) { message in
                            try Pearl.sign(message: message, with: privateKey)
                        }
                        newAddresses.append(address)
                    }
                    
                    if !newAddresses.isEmpty {
                        let update = WalletUpdate(walletID: wallet.walletID, addresses: newAddresses)
                        updates.append(update)
                    }
                }
                Logger.login.info(category: "TIP+Web3", message: "Update addresses for: \(updates.map(\.walletID))")
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for update in updates {
                        group.addTask {
                            let addresses = try await RouteAPI.updateWallet(
                                id: update.walletID,
                                appendingAddresses: update.addresses
                            )
                            Web3AddressDAO.shared.save(addresses: addresses)
                            Logger.login.info(category: "TIP+Web3", message: "\(update.walletID) addresses updated")
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
            Logger.login.info(category: "TIP+Web3", message: "Default common wallet registered")
        }
    }
    
    private static func deriveBitcoinPrivateKey(
        spendKey: Data,
        path: DerivationPath
    ) throws -> Data {
        let masterKey = try ExtendedKey(seed: spendKey, curve: .secp256k1)
        let derivation = try masterKey.deriveUsingSecp256k1(path: path)
        return derivation.key
    }
    
    private static func derivePearlPrivateKey(
        spendKey: Data,
        path: DerivationPath
    ) throws -> Data {
        let masterKey = try ExtendedKey(seed: spendKey, curve: .secp256k1)
        let derivation = try masterKey.deriveUsingSecp256k1(path: path)
        return derivation.key
    }
    
    private static func deriveEthereumPrivateKey(
        spendKey: Data,
        path: DerivationPath
    ) throws -> Data {
        let masterKey = try ExtendedKey(seed: spendKey, curve: .secp256k1)
        let derivation = try masterKey.deriveUsingSecp256k1(path: path)
        return derivation.key
    }
    
    private static func deriveSolanaPrivateKey(
        spendKey: Data,
        path: DerivationPath
    ) throws -> Data {
        let masterKey = try ExtendedKey(seed: spendKey, curve: .secp256k1)
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
