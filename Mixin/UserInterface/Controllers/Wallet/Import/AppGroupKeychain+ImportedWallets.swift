import Foundation
import MixinServices

// MARK: - Mnemonics
extension AppGroupKeychain {
    
    // Key is wallet id, value is encrypted mnemonics
    typealias ImportedMnemonicsStorage = [String: EncryptedBIP39Mnemonics]
    
    static func allImportedMnemonics() -> ImportedMnemonicsStorage {
        guard let data = encryptedImportedWalletMnemonics else {
            return [:]
        }
        do {
            return try PropertyListDecoder.default.decode(ImportedMnemonicsStorage.self, from: data)
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
            return [:]
        }
    }
    
    static func importedMnemonics(walletID: String) -> EncryptedBIP39Mnemonics? {
        allImportedMnemonics()[walletID]
    }
    
    static func setImportedMnemonics(_ mnemonics: EncryptedBIP39Mnemonics, forWalletID id: String) {
        var allMnemonics = allImportedMnemonics()
        allMnemonics[id] = mnemonics
        do {
            let data = try PropertyListEncoder.default.encode(allMnemonics)
            Logger.general.debug(category: "AppGroupKeychain", message: "Save wallet keys \(data.count)")
            encryptedImportedWalletMnemonics = data
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
        }
    }
    
    static func deleteImportedMnemonics(walletID: String) {
        var allMnemonics = allImportedMnemonics()
        do {
            allMnemonics[walletID] = nil
            encryptedImportedWalletMnemonics = try PropertyListEncoder.default.encode(allMnemonics)
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
        }
    }
    
    static func deleteAllImportedMnemonics() {
        encryptedImportedWalletMnemonics = nil
    }
    
}

// MARK: - Private Keys
extension AppGroupKeychain {
    
    // Key is wallet id, value is encrypted private key
    typealias ImportedPrivateKeyStorage = [String: EncryptedPrivateKey]
    
    static func allImportedPrivateKey() -> ImportedPrivateKeyStorage {
        guard let data = encryptedImportedWalletPrivateKeys else {
            return [:]
        }
        do {
            return try PropertyListDecoder.default.decode(ImportedPrivateKeyStorage.self, from: data)
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
            return [:]
        }
    }
    
    static func importedPrivateKey(walletID: String) -> EncryptedPrivateKey? {
        allImportedPrivateKey()[walletID]
    }
    
    static func setImportedPrivateKey(_ key: EncryptedPrivateKey, forWalletID id: String) {
        var keys = allImportedPrivateKey()
        keys[id] = key
        do {
            let data = try PropertyListEncoder.default.encode(keys)
            Logger.general.debug(category: "AppGroupKeychain", message: "Save wallet keys \(data.count)")
            encryptedImportedWalletPrivateKeys = data
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
        }
    }
    
    static func deleteImportedPrivateKey(walletID: String) {
        var keys = allImportedPrivateKey()
        do {
            keys[walletID] = nil
            encryptedImportedWalletPrivateKeys = try PropertyListEncoder.default.encode(keys)
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
        }
    }
    
    static func deleteAllImportedPrivateKey() {
        encryptedImportedWalletPrivateKeys = nil
    }
    
}
