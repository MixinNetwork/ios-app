import Foundation
import MixinServices

// MARK: - Mnemonics
extension AppGroupKeychain {
    
    // Key is wallet id, value is encrypted mnemonics
    private typealias ImportedMnemonicsStorage = [String: EncryptedBIP39Mnemonics]
    
    static func importedMnemonics(walletID: String) -> EncryptedBIP39Mnemonics? {
        if let mnemonics = allImportedMnemonics() {
            mnemonics[walletID]
        } else {
            nil
        }
    }
    
    static func setImportedMnemonics(_ mnemonics: EncryptedBIP39Mnemonics, forWalletID id: String) {
        var allMnemonics: ImportedMnemonicsStorage = allImportedMnemonics() ?? [:]
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
        guard var mnemonics = allImportedMnemonics() else {
            return
        }
        do {
            mnemonics[walletID] = nil
            encryptedImportedWalletMnemonics = try PropertyListEncoder.default.encode(mnemonics)
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
        }
    }
    
    static func deleteAllImportedMnemonics() {
        encryptedImportedWalletMnemonics = nil
    }
    
    private static func allImportedMnemonics() -> ImportedMnemonicsStorage? {
        guard let data = encryptedImportedWalletMnemonics else {
            return nil
        }
        do {
            return try PropertyListDecoder.default.decode(ImportedMnemonicsStorage.self, from: data)
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
            return nil
        }
    }
    
}

// MARK: - Private Keys
extension AppGroupKeychain {
    
    // Key is wallet id, value is encrypted private key
    private typealias ImportedPrivateKeyStorage = [String: EncryptedPrivateKey]
    
    static func importedPrivateKey(walletID: String) -> EncryptedPrivateKey? {
        if let keys = allImportedPrivateKey() {
            keys[walletID]
        } else {
            nil
        }
    }
    
    static func setImportedPrivateKey(_ key: EncryptedPrivateKey, forWalletID id: String) {
        var allPrivateKey: ImportedPrivateKeyStorage = allImportedPrivateKey() ?? [:]
        allPrivateKey[id] = key
        do {
            let data = try PropertyListEncoder.default.encode(allPrivateKey)
            Logger.general.debug(category: "AppGroupKeychain", message: "Save wallet keys \(data.count)")
            encryptedImportedWalletPrivateKeys = data
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
        }
    }
    
    static func deleteImportedPrivateKey(walletID: String) {
        guard var keys = allImportedPrivateKey() else {
            return
        }
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
    
    private static func allImportedPrivateKey() -> ImportedPrivateKeyStorage? {
        guard let data = encryptedImportedWalletPrivateKeys else {
            return nil
        }
        do {
            return try PropertyListDecoder.default.decode(ImportedPrivateKeyStorage.self, from: data)
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
            return nil
        }
    }
    
}
