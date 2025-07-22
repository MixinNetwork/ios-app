import Foundation
import MixinServices

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
            encryptedWalletPrivateKeys = data
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
            encryptedWalletPrivateKeys = try PropertyListEncoder.default.encode(mnemonics)
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
        }
    }
    
    static func deleteAllImportedMnemonics() {
        encryptedWalletPrivateKeys = nil
    }
    
    private static func allImportedMnemonics() -> ImportedMnemonicsStorage? {
        guard let data = encryptedWalletPrivateKeys else {
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
