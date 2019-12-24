import Foundation
import LocalAuthentication

public class Keychain {
    
    public static let shared = Keychain()
    
    private let secKeySize = 256
    private let secKeyType = kSecAttrKeyTypeECSECPrimeRandom
    private let secLabel = "one.mixin.ios.keychain.secureenclave"

    private let keyDeviceId = "device_id"
    private let keyEncryptedPIN = "encrypted_pin"
    private let authenticationService = "one.mixin.ios.authentication"
    
    private func getData(_ key: String) -> Data? {
        let query: [CFString: Any] = [kSecAttrService: authenticationService,
                                      kSecClass: kSecClassGenericPassword,
                                      kSecAttrAccount: key,
                                      kSecReturnData: kCFBooleanTrue!,
                                      kSecMatchLimit: kSecMatchLimitOne,
                                      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    private func getString(_ key: String) -> String? {
        guard let data = getData(key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private func set(_ value: String, key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        return set(data, key: key)
    }

    @discardableResult
    private func remove(_ key: String) -> Bool {
        let attributes = [kSecAttrService: authenticationService,
                          kSecClass: kSecClassGenericPassword,
                          kSecAttrAccount: key,
                          kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary
        return SecItemDelete(attributes) == errSecSuccess
    }

    @discardableResult
    func set(_ value: Data, key: String) -> Bool {
        let query: [CFString: Any] = [kSecAttrService: authenticationService,
                                           kSecClass: kSecClassGenericPassword,
                                           kSecAttrAccount: key,
                                           kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        switch SecItemCopyMatching(query as CFDictionary, nil) {
        case errSecSuccess:
            return SecItemUpdate(query as CFDictionary, [kSecValueData: value] as CFDictionary) == errSecSuccess
        case errSecItemNotFound:
            var attributes = query
            attributes[kSecValueData] = value
            return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
        default:
            return false
        }
    }
}

public extension Keychain {

    func getDeviceId() -> String {
        var deviceId = getString(keyDeviceId) ?? ""
        if deviceId.isEmpty {
            deviceId = UUID().uuidString.lowercased()
            set(deviceId, key: keyDeviceId)
        }
        return deviceId
    }

}

public extension Keychain {

    @discardableResult
    func storePIN(pin: String) -> Bool {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if context.biometryType == .touchID {
                return storePIN(pin: pin, prompt: Localized.WALLET_STORE_ENCRYPTED_PIN(biometricType: Localized.WALLET_TOUCH_ID))
            } else if context.biometryType == .faceID {
                return storePIN(pin: pin, prompt: Localized.WALLET_STORE_ENCRYPTED_PIN(biometricType: Localized.WALLET_FACE_ID))
            }
        }

        return false
    }

    func storePIN(pin: String, prompt: String) -> Bool {
        guard let privateKey = getPrivateKeyRef(prompt: prompt) ?? generateKey() else {
            return false
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey), let externalKey = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            return false
        }
        guard let encryptedString = encryptPIN(pin: pin, publicKey: externalKey) else {
            return false
        }

        return set(encryptedString, key: keyEncryptedPIN)
    }

    func getPIN(prompt: String) -> String? {
        guard let encryptedString = getString(keyEncryptedPIN), let encryptedData = Data(base64Encoded: encryptedString) else {
            Reporter.report(error: MixinServicesError.extractEncryptedPin)
            AppGroupUserDefaults.Wallet.payWithBiometricAuthentication = false
            return nil
        }
        guard let privateKey = getPrivateKeyRef(prompt: prompt), SecKeyIsAlgorithmSupported(privateKey, .decrypt, .eciesEncryptionStandardX963SHA256AESGCM) else {
            return nil
        }
        guard let decryptData = SecKeyCreateDecryptedData(privateKey, .eciesEncryptionStandardX963SHA256AESGCM, encryptedData as CFData, nil) else {
            return nil
        }
        
        return String(data: decryptData as Data, encoding: .utf8)
    }

    func clearPIN() {
        AppGroupUserDefaults.Wallet.payWithBiometricAuthentication = false
        remove(keyEncryptedPIN)
    }

    private func encryptPIN(pin: String, publicKey: CFData) -> String? {
        guard let pinData = pin.data(using: .utf8) else {
            return nil
        }
        let attributes = [ kSecAttrKeyType: secKeyType,
                           kSecAttrKeyClass: kSecAttrKeyClassPublic,
                           kSecAttrKeySizeInBits: secKeySize ] as CFDictionary
        guard let newPublicKey = SecKeyCreateWithData(publicKey, attributes, nil) else {
            return nil
        }

        guard let encryptData = SecKeyCreateEncryptedData(newPublicKey, SecKeyAlgorithm.eciesEncryptionStandardX963SHA256AESGCM, pinData as CFData, nil) else {
            return nil
        }

        return (encryptData as Data).base64EncodedString()
    }

    private func getPrivateKeyRef(prompt: String) -> SecKey? {
        let parameters = [ kSecClass: kSecClassKey,
                           kSecAttrKeyType: secKeyType,
                           kSecAttrKeySizeInBits: secKeySize,
                           kSecAttrLabel: secLabel,
                           kSecReturnRef: kCFBooleanTrue!,
                           kSecUseOperationPrompt: prompt ] as CFDictionary
        var privateKey: AnyObject?
        guard SecItemCopyMatching(parameters, &privateKey) == errSecSuccess else {
            return nil
        }
        return privateKey as! SecKey?
    }

    private func generateKey() -> SecKey? {
        guard let aclObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, [.privateKeyUsage, .touchIDAny], nil) else {
            return nil
        }

        let privateKeyParams: [CFString: Any] = [kSecAttrAccessControl: aclObject,
                                                 kSecAttrIsPermanent: kCFBooleanTrue!]

        let parameters = [ kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                           kSecAttrKeyType: secKeyType,
                           kSecAttrKeySizeInBits: secKeySize,
                           kSecAttrLabel: secLabel,
                           kSecPrivateKeyAttrs: privateKeyParams ] as CFDictionary
        return SecKeyCreateRandomKey(parameters, nil)
    }

}
