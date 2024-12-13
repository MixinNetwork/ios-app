import Foundation
import CommonCrypto
import MixinServices

enum PINEncryptor {
    
    enum Error: Swift.Error {
        case invalidPIN
        case missingPINToken
        case ivGeneration
        case encryption(Swift.Error)
        case legacyPINAfterTIPSet
    }
    
    private static let queue = DispatchQueue(label: "one.mixin.service.PINEncryptor")

    static func encrypt<Response>(
        pin: String,
        tipBody: @escaping () throws -> Data,
        onFailure: @escaping (MixinAPI.Result<Response>) -> Void,
        onSuccess: @escaping (String) -> Void
    ) {
        switch TIP.status {
        case .none, .needsInitialize:
            Logger.tip.error(category: "PINEncryptor", message: "Invalid status: \(TIP.status)")
            assertionFailure("Invalid TIP status")
        case .needsMigrate:
            queue.async {
                switch encrypt(pin: pin) {
                case .success(let encrypted):
                    onSuccess(encrypted)
                case .failure(let error):
                    DispatchQueue.main.async {
                        onFailure(.failure(.pinEncryptionFailed(error)))
                    }
                }
            }
        case .ready:
            Task {
                do {
                    let priv = try await TIP.getOrRecoverTIPPriv(pin: pin)
                    let body = try tipBody()
                    let encrypted = try await TIP.encryptTIPPIN(tipPriv: priv, target: body)
                    await MainActor.run {
                        onSuccess(encrypted)
                    }
                } catch {
                    await MainActor.run {
                        Logger.tip.error(category: "PINEncryptor", message: "Failed to encrypt: \(error)")
                        if let error = error as? MixinAPIError {
                            onFailure(.failure(error))
                        } else {
                            onFailure(.failure(.pinEncryptionFailed(error)))
                        }
                    }
                }
            }

        }
    }
    
    private static func encrypt(pin: String) -> Result<String, Error> {
        let pinToken: Data
        if let token = AppGroupKeychain.pinToken {
            pinToken = token
        } else if let encoded = AppGroupUserDefaults.Account.pinToken, let token = Data(base64Encoded: encoded) {
            pinToken = token
        } else {
            return .failure(.missingPINToken)
        }
        guard let pinData = pin.data(using: .utf8) else {
            return .failure(.invalidPIN)
        }
        guard let iv = Data(withNumberOfSecuredRandomBytes: kCCBlockSizeAES128) else {
            return .failure(.ivGeneration)
        }
        
        let time = UInt64(Date().timeIntervalSince1970)
        let timeData = time.data(endianness: .little)
        
        var iterator: UInt64 = 0
        PropertiesDAO.shared.updateValue(forKey: .iterator, type: UInt64.self) { databaseValue in
            let userDefaultsValue = AppGroupUserDefaults.Crypto.iterator
            if let databaseValue = databaseValue {
                if databaseValue != userDefaultsValue {
                    Logger.general.warn(category: "PIN", message: "database: \(databaseValue), defaults: \(userDefaultsValue)")
                }
                iterator = max(databaseValue, userDefaultsValue)
            } else {
                iterator = userDefaultsValue
                Logger.general.info(category: "PIN", message: "Iterator initialized to \(userDefaultsValue)")
            }
            let nextIterator = iterator + 1
            AppGroupUserDefaults.Crypto.iterator = nextIterator
            return nextIterator
        }
        let iteratorData = iterator.data(endianness: .little)
        Logger.general.info(category: "PIN", message: "Encrypt with it: \(iterator)")
        
        let plain = pinData + timeData + iteratorData
        do {
            let encrypted = try AESCryptor.encrypt(plain, with: pinToken)
            let base64Encoded = encrypted.base64RawURLEncodedString()
            return .success(base64Encoded)
        } catch {
            return .failure(.encryption(error))
        }
    }
    
}
