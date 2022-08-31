import Foundation
import Tip
import CryptoKit

public enum TIP {
    
    public enum Status {
        case ready
        case needsInitialize
        case needsMigrate
        case unknown
    }
    
    public enum NodeCounterStatus {
        case balanced
        case greaterThanServer(InterruptionContext)
        case inconsistency(InterruptionContext)
    }
    
    public enum Step {
        case creating
        case connecting
        case synchronizing(Float)
    }
    
    public struct InterruptionContext {
        public let nodeCounter: UInt64
        public let failedSigners: [TIPSigner]
    }
    
    public static let didUpdateNotification = Notification.Name("one.mixin.service.tip.update")
    
    enum Error: Swift.Error {
        case missingPINToken
        case unableToGenerateSecuredRandom
        case invalidPIN
        case identitySeedHash
        case invalidSignature
        case incorrectPIN
        case missingSessionSecret
        case generateSTSeed
        case invalidSTSeed
        case unableToSignTimestamp
        case generatePrivTIPKey
        case invalidAggSig
        case noAccount
        case invalidTIPPriv
        case unableToSignTarget
        case unableToHashTIPPrivKey
        case tipCounterExceedsNodeCounter
        case invalidCounterGroups
    }
    
    public static var status: Status {
        guard let account = LoginManager.shared.account else {
            return .unknown
        }
        if account.tipCounter == 0 {
            if account.hasPIN {
                return .needsMigrate
            } else {
                return .needsInitialize
            }
        } else {
            return .ready
        }
    }
    
    static func encryptPIN(key: Data, code: Data) throws -> String {
        let pinData = code
            + UInt64(Date().timeIntervalSince1970).data(endianness: .little)
            + pinIterator().data(endianness: .little)
        let based = try AESCryptor.encrypt(pinData, with: key).base64RawURLEncodedString()
        return based
    }
    
    static func encryptTIPPIN(tipPriv: Data, target: Data) throws -> String {
        guard let pinToken = AppGroupKeychain.pinToken else {
            throw Error.missingPINToken
        }
        let privSeed = Data(SHA256.hash(data: tipPriv))
        guard let privateKey = Ed25519PrivateKey(rfc8032Representation: privSeed) else {
            throw Error.invalidTIPPriv
        }
        guard let sig = privateKey.signature(for: target) else {
            throw Error.unableToSignTarget
        }
        let pinData = sig
            + UInt64(Date().timeIntervalSince1970).data(endianness: .little)
            + pinIterator().data(endianness: .little)
        let based = try AESCryptor.encrypt(pinData, with: pinToken).base64RawURLEncodedString()
        return based
    }
    
    static func encryptTIPPIN(pin: String, pinToken: Data, target: Data) async throws -> String {
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        let tipPriv: Data
        if let savedTIPPriv = AppGroupKeychain.tipPriv {
            let aesKey = try await getAESKey(pinData: pinData, pinToken: pinToken)
            guard let tipPrivKey = SHA3_256.hash(data: aesKey + pinData) else {
                throw Error.unableToHashTIPPrivKey
            }
            tipPriv = try AESCryptor.decrypt(savedTIPPriv, with: tipPrivKey)
        } else {
            tipPriv = try await createTIPPriv(pin: pin,
                                              failedSigners: [],
                                              legacyPIN: nil,
                                              forRecover: true,
                                              progressHandler: nil)
        }
        return try encryptTIPPIN(tipPriv: tipPriv, target: target)
    }
    
    static func pinIterator() -> UInt64 {
        var iterator: UInt64 = 0
        PropertiesDAO.shared.updateValue(forKey: .iterator, type: UInt64.self) { databaseValue in
            let userDefaultsValue = AppGroupUserDefaults.Crypto.iterator
            if let databaseValue = databaseValue {
                if databaseValue != userDefaultsValue {
                    Logger.general.warn(category: "TIP", message: "database: \(databaseValue), defaults: \(userDefaultsValue)")
                }
                iterator = max(databaseValue, userDefaultsValue)
            } else {
                iterator = userDefaultsValue
                Logger.general.info(category: "TIP", message: "Iterator initialized to \(userDefaultsValue)")
            }
            let nextIterator = iterator + 1
            AppGroupUserDefaults.Crypto.iterator = nextIterator
            return nextIterator
        }
        Logger.general.info(category: "TIP", message: "Encrypt with it: \(iterator)")
        return iterator
    }
    
    static func ephemeralSeed(pinToken: Data) async throws -> Data {
        if let seed = AppGroupKeychain.ephemeralSeed {
            Logger.general.debug(category: "TIP", message: "Using saved ephemeral: \(seed.hexEncodedString())")
            return seed
        } else {
            let ephemerals = try await TIPAPI.ephemerals()
            if let newest = ephemerals.max(by: { $0.createdAt > $1.createdAt }), let decoded = Data(base64URLEncoded: newest.seed) {
                let seed = try AESCryptor.decrypt(decoded, with: pinToken)
                try await TIPAPI.updateEphemeral(base64URLEncoded: newest.seed)
                AppGroupKeychain.ephemeralSeed = seed
                Logger.general.debug(category: "TIP", message: "Using retrieved ephemeral: \(seed.hexEncodedString())")
                return seed
            } else if let seed = Data(withNumberOfSecuredRandomBytes: 32) {
                let encrypted = try AESCryptor.encrypt(seed, with: pinToken)
                let encoded = encrypted.base64RawURLEncodedString()
                try await TIPAPI.updateEphemeral(base64URLEncoded: encoded)
                AppGroupKeychain.ephemeralSeed = seed
                Logger.general.debug(category: "TIP", message: "Using updated ephemeral: \(seed.hexEncodedString())")
                return seed
            } else {
                throw Error.unableToGenerateSecuredRandom
            }
        }
    }
    
    public static func createTIPPriv(
        pin: String,
        failedSigners: [TIPSigner],
        legacyPIN: String?,
        forRecover: Bool,
        progressHandler: (@MainActor (Step) -> Void)?
    ) async throws -> Data {
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        guard let pinToken = AppGroupKeychain.pinToken else {
            throw Error.missingPINToken
        }
        
        await progressHandler?(.creating)
        let ephemeralSeed = try await ephemeralSeed(pinToken: pinToken)
        let (identityPriv, watcher) = try await TIPIdentityManager.identityPair(pinData: pinData, pinToken: pinToken)
        
        await progressHandler?(.connecting)
        let aggSig = try await TIPNode.sign(identityPriv: identityPriv,
                                            ephemeral: ephemeralSeed,
                                            watcher: watcher,
                                            assigneePriv: nil,
                                            failedSigners: [],
                                            forRecover: false,
                                            progressHandler: progressHandler)
        let privSeed = Data(SHA256.hash(data: aggSig))
        guard let priv = Ed25519PrivateKey(rfc8032Representation: privSeed) else {
            throw Error.invalidSignature
        }
        let pub = priv.publicKey.rawRepresentation
        if let localPub = LoginManager.shared.account?.tipKey, !localPub.isEmpty, pub != localPub {
            throw Error.incorrectPIN
        }
        
        try await encryptAndSave(pinData: pinData, pinToken: pinToken, aggSig: aggSig)
        
        if forRecover {
            return aggSig
        }
        
        let oldEncryptedPIN: String?
        if let legacyPIN = legacyPIN {
            if let data = legacyPIN.data(using: .utf8) {
                oldEncryptedPIN = try encryptPIN(key: pinToken, code: data)
            } else {
                throw Error.invalidPIN
            }
        } else {
            oldEncryptedPIN = nil
        }
        let new = try encryptPIN(key: pinToken, code: pub + UInt64(1).data(endianness: .big))
        let request = PINRequest(pin: new, oldPIN: oldEncryptedPIN, timestamp: nil)
        let account = try await AccountAPI.updatePIN(request: request)
        LoginManager.shared.setAccount(account)
        await MainActor.run {
            NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
        }
        return aggSig
    }
    
    public static func updateTIPPriv(
        pin: String,
        newPIN: String,
        nodeSuccess: Bool,
        failedSigners: [TIPSigner],
        progressHandler: (@MainActor (Step) -> Void)?
    ) async throws -> Data {
        Logger.general.debug(category: "TIP", message: "Update priv with nodeSuccess: \(nodeSuccess), failedSigners: \(failedSigners)")
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        guard let newPINData = newPIN.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        guard let pinToken = AppGroupKeychain.pinToken else {
            throw Error.missingPINToken
        }
        
        await progressHandler?(.creating)
        let ephemeralSeed = try await ephemeralSeed(pinToken: pinToken)
        let (identityPriv, watcher) = try await TIPIdentityManager.identityPair(pinData: pinData, pinToken: pinToken)
        let (assigneePriv, _) = try await TIPIdentityManager.identityPair(pinData: newPINData, pinToken: pinToken)
        
        await progressHandler?(.connecting)
        let aggSig: Data
        if nodeSuccess {
            aggSig = try await TIPNode.sign(identityPriv: assigneePriv,
                                            ephemeral: ephemeralSeed,
                                            watcher: watcher,
                                            assigneePriv: nil,
                                            failedSigners: [],
                                            forRecover: false,
                                            progressHandler: progressHandler)
        } else {
            aggSig = try await TIPNode.sign(identityPriv: identityPriv,
                                            ephemeral: ephemeralSeed,
                                            watcher: watcher,
                                            assigneePriv: assigneePriv,
                                            failedSigners: failedSigners,
                                            forRecover: false,
                                            progressHandler: progressHandler)
        }
        
        try await encryptAndSave(pinData: newPINData, pinToken: pinToken, aggSig: aggSig)
        
        let privSeed = Data(SHA256.hash(data: aggSig))
        guard let privateKey = Ed25519PrivateKey(rfc8032Representation: privSeed) else {
            throw Error.invalidAggSig
        }
        let pub = privateKey.publicKey.rawRepresentation
        guard let counter = LoginManager.shared.account?.tipCounter else {
            throw Error.noAccount
        }
        let timestamp = try TIPBody.verify(timestamp: counter)
        let oldPIN = try encryptTIPPIN(tipPriv: aggSig, target: timestamp)
        let newEncryptPIN = try encryptPIN(key: pinToken, code: pub + (counter + 1).data(endianness: .big))
        let request = PINRequest(pin: newEncryptPIN, oldPIN: oldPIN, timestamp: nil)
        let account = try await AccountAPI.updatePIN(request: request)
        LoginManager.shared.setAccount(account)
        await MainActor.run {
            NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
        }
        return aggSig
    }
    
    public static func checkCounter(_ tipCounter: UInt64) async throws -> NodeCounterStatus {
        guard let pinToken = AppGroupKeychain.pinToken else {
            throw Error.missingPINToken
        }
        let watcher = try await TIPIdentityManager.watcher(pinToken: pinToken)
        let counters = try await TIPNode.watch(watcher: watcher)
        if counters.isEmpty {
            return .balanced
        }
        if counters.count != TIPConfig.current.signers.count {
            Logger.general.warn(category: "TIP", message: "Watch count: \(counters.count), node count: \(TIPConfig.current.signers.count)")
        }
        let groups = counters.reduce(into: [UInt64: [TIPNode.Counter]]()) { (result, counter) in
            var counters = result[counter.value] ?? []
            counters.append(counter)
            result[counter.value] = counters
        }
        if groups.count <= 1 {
            let nodeCounter = counters[0].value
            if nodeCounter == tipCounter {
                return .balanced
            } else if nodeCounter < tipCounter {
                throw Error.tipCounterExceedsNodeCounter
            } else {
                let context = InterruptionContext(nodeCounter: nodeCounter, failedSigners: [])
                return .greaterThanServer(context)
            }
        } else if groups.count == 2 {
            let maxCounter = groups.keys.max()!
            let failedNodes = groups[groups.keys.min()!]!
            let context = InterruptionContext(nodeCounter: maxCounter, failedSigners: failedNodes.map(\.signer))
            return .inconsistency(context)
        } else {
            throw Error.invalidCounterGroups
        }
    }
    
    private static func encryptAndSave(pinData: Data, pinToken: Data, aggSig: Data) async throws -> Data {
        let aesKey = try await generateAESKey(pinData: pinData, pinToken: pinToken)
        guard let tipPrivKey = SHA3_256.hash(data: aesKey + pinData) else {
            throw Error.generatePrivTIPKey
        }
        let tipPriv = try AESCryptor.encrypt(aggSig, with: tipPrivKey)
        AppGroupKeychain.tipPriv = tipPriv
        return aggSig
    }
    
    private static func generateAESKey(pinData: Data, pinToken: Data) async throws -> Data {
        guard let sessionPriv = AppGroupKeychain.sessionSecret else {
            throw Error.missingSessionSecret
        }
        
        guard let stSeed = SHA3_256.hash(data: sessionPriv + pinData) else {
            throw Error.generateSTSeed
        }
        guard let stPriv = Ed25519PrivateKey(rfc8032Representation: stSeed) else {
            throw Error.invalidSTSeed
        }
        let stPub = stPriv.publicKey.rawRepresentation
        guard let key = Data(withNumberOfSecuredRandomBytes: 32) else {
            throw Error.unableToGenerateSecuredRandom
        }
        
        let seedBase64 = try AESCryptor.encrypt(key, with: pinToken).base64RawURLEncodedString()
        let secretBase64 = try AESCryptor.encrypt(stPub, with: pinToken).base64RawURLEncodedString()
        let timestamp = UInt64(Date().timeIntervalSince1970) * UInt64(NSEC_PER_SEC)
        
        let sigBase64 = try sign(timestamp: timestamp, with: stPriv)
        let request = TIPSecretUpdateRequest(seed: seedBase64,
                                             secret: secretBase64,
                                             signature: sigBase64,
                                             timestamp: timestamp)
        _ = try await TIPAPI.updateSecret(request: request)
        return key
    }
    
    private static func getAESKey(pinData: Data, pinToken: Data) async throws -> Data {
        guard let sessionPriv = AppGroupKeychain.sessionSecret else {
            throw Error.missingSessionSecret
        }
        
        guard let stSeed = SHA3_256.hash(data: sessionPriv + pinData) else {
            throw Error.generateSTSeed
        }
        guard let stPriv = Ed25519PrivateKey(rfc8032Representation: stSeed) else {
            throw Error.invalidSTSeed
        }
        let timestamp = UInt64(Date().timeIntervalSince1970) * UInt64(NSEC_PER_SEC)
        
        let sigBase64 = try sign(timestamp: timestamp, with: stPriv)
        let request = TIPSecretReadRequest(signature: sigBase64, timestamp: timestamp)
        let seed = try await TIPAPI.readSecret(request: request).seed
        return try AESCryptor.decrypt(seed, with: pinToken)
    }
    
    private static func sign(timestamp: UInt64, with key: Ed25519PrivateKey) throws -> String {
        let body = try TIPBody.verify(timestamp: timestamp)
        guard let signature = key.signature(for: body) else {
            throw Error.unableToSignTimestamp
        }
        return signature.base64RawURLEncodedString()
    }
    
}
