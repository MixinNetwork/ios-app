import Foundation
import MixinServices

extension AppGroupKeychain {
    
    // Key is address, value is private key
    typealias WalletPrivateKeyStorage = [String: Data]
    
    static func encryptedWalletPrivateKey(address: String) -> Data? {
        guard let data = encryptedWalletPrivateKeys else {
            return nil
        }
        do {
            let keys = try PropertyListDecoder.default.decode(WalletPrivateKeyStorage.self, from: data)
            return keys[address]
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
            return nil
        }
    }
    
    static func upsertEncryptedWalletPrivateKeys(_ keys: WalletPrivateKeyStorage) {
        var allKeys: WalletPrivateKeyStorage
        if let data = encryptedWalletPrivateKeys {
            do {
                allKeys = try PropertyListDecoder.default.decode(WalletPrivateKeyStorage.self, from: data)
            } catch {
                Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
                allKeys = [:]
            }
        } else {
            allKeys = [:]
        }
        for (address, key) in keys {
            allKeys[address] = key
        }
        do {
            let data = try PropertyListEncoder.default.encode(allKeys)
            Logger.general.debug(category: "AppGroupKeychain", message: "Save wallet keys \(data.count)")
            encryptedWalletPrivateKeys = data
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
        }
    }
    
    static func deleteEncryptedWalletPrivateKey(addresses: [String]) {
        guard let data = encryptedWalletPrivateKeys else {
            return
        }
        do {
            var keys = try PropertyListDecoder.default.decode(WalletPrivateKeyStorage.self, from: data)
            for address in addresses {
                keys.removeValue(forKey: address)
            }
            encryptedWalletPrivateKeys = try PropertyListEncoder.default.encode(keys)
        } catch {
            Logger.general.error(category: "AppGroupKeychain", message: "\(error)")
        }
    }
    
}
