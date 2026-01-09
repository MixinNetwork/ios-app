import Foundation
import web3
import MixinServices

extension Web3Wallet {
    
    enum DerivationError: Error {
        case unknownCategory
        case invalidCategory
        case missingDerivationPath
        case missingPrivateKey
    }
    
    func bitcoinPrivateKey(pin: String, address: Web3Address) async throws -> Data {
        switch category.knownCase {
        case .classic:
            let path = if let string = address.path {
                try DerivationPath(string: string)
            } else {
                try DerivationPath.bitcoin(index: 0)
            }
            return try await TIP.deriveBitcoinPrivateKey(pin: pin, path: path)
        case .importedMnemonic:
            guard let pathString = address.path else {
                throw DerivationError.missingDerivationPath
            }
            let path = try DerivationPath(string: pathString)
            let encryptedMnemonics = AppGroupKeychain.importedMnemonics(walletID: walletID)
            guard let encryptedMnemonics else {
                throw DerivationError.missingPrivateKey
            }
            let key = try await TIP.importedWalletEncryptionKey(pin: pin)
            let mnemonics = try encryptedMnemonics.decrypt(with: key)
            return try mnemonics.deriveForBitcoin(path: path).privateKey
        case .importedPrivateKey:
            let encryptedPrivateKey = AppGroupKeychain.importedPrivateKey(walletID: walletID)
            guard let encryptedPrivateKey else {
                throw DerivationError.missingPrivateKey
            }
            let key = try await TIP.importedWalletEncryptionKey(pin: pin)
            return try encryptedPrivateKey.decrypt(with: key)
        case .watchAddress:
            throw DerivationError.invalidCategory
        case .none:
            throw DerivationError.unknownCategory
        }
    }
    
    func ethereumAccount(pin: String, address: Web3Address) async throws -> EthereumAccount {
        let privateKey: Data
        switch category.knownCase {
        case .classic:
            let path = if let string = address.path {
                try DerivationPath(string: string)
            } else {
                try DerivationPath.evm(index: 0)
            }
            privateKey = try await TIP.deriveEthereumPrivateKey(pin: pin, path: path)
        case .importedMnemonic:
            guard let pathString = address.path else {
                throw DerivationError.missingDerivationPath
            }
            let path = try DerivationPath(string: pathString)
            let encryptedMnemonics = AppGroupKeychain.importedMnemonics(walletID: walletID)
            guard let encryptedMnemonics else {
                throw DerivationError.missingPrivateKey
            }
            let key = try await TIP.importedWalletEncryptionKey(pin: pin)
            let mnemonics = try encryptedMnemonics.decrypt(with: key)
            privateKey = try mnemonics.deriveForEVM(path: path).privateKey
        case .importedPrivateKey:
            let encryptedPrivateKey = AppGroupKeychain.importedPrivateKey(walletID: walletID)
            guard let encryptedPrivateKey else {
                throw DerivationError.missingPrivateKey
            }
            let key = try await TIP.importedWalletEncryptionKey(pin: pin)
            privateKey = try encryptedPrivateKey.decrypt(with: key)
        case .watchAddress:
            throw DerivationError.invalidCategory
        case .none:
            throw DerivationError.unknownCategory
        }
        let keyStorage = InPlaceKeyStorage(raw: privateKey)
        return try EthereumAccount(keyStorage: keyStorage)
    }
    
    func solanaPrivateKey(pin: String, address: Web3Address) async throws -> Data {
        switch category.knownCase {
        case .classic:
            let path = if let string = address.path {
                try DerivationPath(string: string)
            } else {
                try DerivationPath.solana(index: 0)
            }
            return try await TIP.deriveSolanaPrivateKey(pin: pin, path: path)
        case .importedMnemonic:
            guard let pathString = address.path else {
                throw DerivationError.missingDerivationPath
            }
            let path = try DerivationPath(string: pathString)
            let encryptedMnemonics = AppGroupKeychain.importedMnemonics(walletID: walletID)
            guard let encryptedMnemonics else {
                throw DerivationError.missingPrivateKey
            }
            let key = try await TIP.importedWalletEncryptionKey(pin: pin)
            let mnemonics = try encryptedMnemonics.decrypt(with: key)
            return try mnemonics.deriveForSolana(path: path).privateKey
        case .importedPrivateKey:
            let encryptedPrivateKey = AppGroupKeychain.importedPrivateKey(walletID: walletID)
            guard let encryptedPrivateKey else {
                throw DerivationError.missingPrivateKey
            }
            let key = try await TIP.importedWalletEncryptionKey(pin: pin)
            return try encryptedPrivateKey.decrypt(with: key)
        case .watchAddress:
            throw DerivationError.invalidCategory
        case .none:
            throw DerivationError.unknownCategory
        }
    }
    
}
