import Foundation
import Alamofire
import Tip

public enum TIP {
    
    public struct InterruptionContext {
        
        public enum Situation {
            case pendingUpdate
            case pendingSign(_ failedSigners: [TIPSigner])
        }
        
        public let action: Action
        public let situation: Situation
        public let maxNodeCounter: UInt64
        
#if DEBUG
        public init(action: Action, situation: Situation, maxNodeCounter: UInt64) {
            self.action = action
            self.situation = situation
            self.maxNodeCounter = maxNodeCounter
        }
#endif
        
        init(account: Account, situation: Situation, maxNodeCounter: UInt64) {
            if maxNodeCounter == 1 {
                if account.hasPIN {
                    self.action = .migrate
                } else {
                    self.action = .create
                }
            } else {
                self.action = .change
            }
            self.situation = situation
            self.maxNodeCounter = maxNodeCounter
        }
        
    }
    
    public enum Action {
        case create
        case change
        case migrate
    }
    
    public enum Status {
        case ready
        case needsInitialize
        case needsMigrate
        case unknown
    }
    
    public enum Progress {
        case creating
        case connecting
        case synchronizing(Float)
    }
    
    public enum Error: Swift.Error {
        case missingPINToken
        case unableToGenerateSecuredRandom
        case invalidPIN
        case identitySeedHash
        case incorrectPIN
        case missingSessionSecret
        case generateSTSeed
        case generateTIPPrivKey
        case hashAggSigToPrivSeed
        case noAccount
        case unableToHashTIPPrivKey
        case tipCounterExceedsNodeCounter
        case invalidCounterGroups
        case hashTIPPrivToPrivSeed
    }
    
    public static let didUpdateNotification = Notification.Name("one.mixin.service.tip.update")
    
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
    
}

extension TIP {
    
    @discardableResult
    public static func createTIPPriv(
        pin: String,
        failedSigners: [TIPSigner],
        legacyPIN: String?,
        forRecover: Bool,
        progressHandler: (@MainActor (Progress) -> Void)?
    ) async throws -> Data {
        Logger.tip.info(category: "TIP", message: "createTIPPriv with failedSigners: \(failedSigners.map(\.index)), legacyPIN: \(legacyPIN != nil), forRecover: \(forRecover)")
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        guard let pinToken = AppGroupKeychain.pinToken else {
            throw Error.missingPINToken
        }
        
        await progressHandler?(.creating)
        let ephemeralSeed = try await ephemeralSeed(pinToken: pinToken)
        Logger.tip.info(category: "TIP", message: "Ephemeral seed ready")
        let (identityPriv, watcher) = try await TIPIdentityManager.identityPair(pinData: pinData, pinToken: pinToken)
        Logger.tip.info(category: "TIP", message: "Identity pair ready")
        
        await progressHandler?(.connecting)
        let aggSig = try await TIPNode.sign(identityPriv: identityPriv,
                                            ephemeral: ephemeralSeed,
                                            watcher: watcher,
                                            assigneePriv: nil,
                                            failedSigners: failedSigners,
                                            forRecover: false,
                                            progressHandler: progressHandler)
        Logger.tip.info(category: "TIP", message: "aggSig ready")
        guard let privSeed = SHA3_256.hash(data: aggSig) else {
            throw Error.hashAggSigToPrivSeed
        }
        let priv = try Ed25519PrivateKey(rawRepresentation: privSeed)
        let pub = priv.publicKey.rawRepresentation
        if let localPub = LoginManager.shared.account?.tipKey, !localPub.isEmpty, pub != localPub {
            throw Error.incorrectPIN
        }
        
        let aesKey = try await generateAESKey(pinData: pinData, pinToken: pinToken)
        Logger.tip.info(category: "TIP", message: "AES key ready")
        if forRecover {
            Logger.tip.info(category: "TIP", message: "Recovering")
            try await encryptAndSaveTIPPriv(pinData: pinData, aggSig: aggSig, aesKey: aesKey)
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
#if DEBUG
        try await MainActor.run {
            if TIPDiagnostic.failPINUpdateServerSideOnce {
                TIPDiagnostic.failPINUpdateServerSideOnce = false
                throw MixinAPIError.httpTransport(.sessionTaskFailed(error: URLError(.badServerResponse)))
            }
        }
#endif
        Logger.tip.info(category: "TIP", message: "Will update PIN")
        let account = try await AccountAPI.updatePIN(request: request)
#if DEBUG
        try await MainActor.run {
            if TIPDiagnostic.failPINUpdateClientSideOnce {
                TIPDiagnostic.failPINUpdateClientSideOnce = false
                throw MixinAPIError.httpTransport(.sessionTaskFailed(error: URLError(.badServerResponse)))
            }
            if TIPDiagnostic.crashAfterUpdatePIN {
                abort()
            }
        }
#endif
        LoginManager.shared.setAccount(account)
        Logger.tip.info(category: "TIP", message: "Local account is updated with tip_counter: \(account.tipCounter)")
        
        try encryptAndSaveTIPPriv(pinData: pinData, aggSig: aggSig, aesKey: aesKey)
        Logger.tip.info(category: "TIP", message: "TIP Priv is saved")
        await MainActor.run {
            NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
        }
        return aggSig
    }
    
    @discardableResult
    public static func updateTIPPriv(
        oldPIN: String?,
        newPIN: String,
        failedSigners: [TIPSigner],
        progressHandler: (@MainActor (Progress) -> Void)?
    ) async throws -> Data {
        Logger.tip.info(category: "TIP", message: "Update priv with oldPIN: \(oldPIN != nil), failedSigners: \(failedSigners.map(\.index))")
        guard let newPINData = newPIN.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        guard let pinToken = AppGroupKeychain.pinToken else {
            throw Error.missingPINToken
        }
        
        await progressHandler?(.creating)
        let ephemeralSeed = try await ephemeralSeed(pinToken: pinToken)
        Logger.tip.info(category: "TIP", message: "Ephemeral seed ready")
        let identityPriv: Data
        let watcher: Data
        let assigneePriv: Data?
        if let oldPIN = oldPIN {
            guard let oldPINData = oldPIN.data(using: .utf8) else {
                throw Error.invalidPIN
            }
            (identityPriv, watcher) = try await TIPIdentityManager.identityPair(pinData: oldPINData, pinToken: pinToken)
            Logger.tip.info(category: "TIP", message: "Identity pair ready")
            assigneePriv = try await TIPIdentityManager.identityPair(pinData: newPINData, pinToken: pinToken).priv
            Logger.tip.info(category: "TIP", message: "assigneePriv ready")
        } else {
            (identityPriv, watcher) = try await TIPIdentityManager.identityPair(pinData: newPINData, pinToken: pinToken)
            Logger.tip.info(category: "TIP", message: "Identity pair ready")
            assigneePriv = nil
            Logger.tip.info(category: "TIP", message: "No assigneePriv needed")
        }
        
        await progressHandler?(.connecting)
        let aggSig = try await TIPNode.sign(identityPriv: identityPriv,
                                            ephemeral: ephemeralSeed,
                                            watcher: watcher,
                                            assigneePriv: assigneePriv,
                                            failedSigners: failedSigners,
                                            forRecover: false,
                                            progressHandler: progressHandler)
        Logger.tip.info(category: "TIP", message: "aggSig ready")
        let aesKey = try await generateAESKey(pinData: newPINData, pinToken: pinToken)
        Logger.tip.info(category: "TIP", message: "AES key ready")
        guard let privSeed = SHA3_256.hash(data: aggSig) else {
            throw Error.hashAggSigToPrivSeed
        }
        let privateKey = try Ed25519PrivateKey(rawRepresentation: privSeed)
        let pub = privateKey.publicKey.rawRepresentation
        guard let counter = LoginManager.shared.account?.tipCounter else {
            throw Error.noAccount
        }
        let body = try TIPBody.verify(timestamp: counter)
        let oldPIN = try encryptTIPPIN(tipPriv: aggSig, target: body)
        let newEncryptPIN = try encryptPIN(key: pinToken, code: pub + (counter + 1).data(endianness: .big))
        let request = PINRequest(pin: newEncryptPIN, oldPIN: oldPIN, timestamp: nil)
        AppGroupKeychain.tipPriv = nil
        Logger.tip.info(category: "TIP", message: "TIP Priv is removed")
#if DEBUG
        try await MainActor.run {
            if TIPDiagnostic.failPINUpdateServerSideOnce {
                TIPDiagnostic.failPINUpdateServerSideOnce = false
                throw MixinAPIError.httpTransport(.sessionTaskFailed(error: URLError(.badServerResponse)))
            }
        }
#endif
        Logger.tip.info(category: "TIP", message: "Will update PIN")
        let account = try await AccountAPI.updatePIN(request: request)
#if DEBUG
        try await MainActor.run {
            if TIPDiagnostic.failPINUpdateClientSideOnce {
                TIPDiagnostic.failPINUpdateClientSideOnce = false
                throw MixinAPIError.httpTransport(.sessionTaskFailed(error: URLError(.badServerResponse)))
            }
            if TIPDiagnostic.crashAfterUpdatePIN {
                abort()
            }
        }
#endif
        LoginManager.shared.setAccount(account)
        Logger.tip.info(category: "TIP", message: "Local account is updated with tip_counter: \(account.tipCounter)")
        try encryptAndSaveTIPPriv(pinData: newPINData, aggSig: aggSig, aesKey: aesKey)
        Logger.tip.info(category: "TIP", message: "TIP Priv is saved")
        await MainActor.run {
            NotificationCenter.default.post(name: Self.didUpdateNotification, object: self)
        }
        return aggSig
    }
    
    public static func checkCounter(with freshAccount: Account? = nil, timeoutInterval: TimeInterval = 15) async throws -> InterruptionContext? {
        let account: Account
        if let freshAccount {
            Logger.tip.info(category: "TIP", message: "Check counter with provided account")
            account = freshAccount
        } else {
            Logger.tip.info(category: "TIP", message: "Reloading account")
            account = try await AccountAPI.me()
            await MainActor.run {
                LoginManager.shared.setAccount(account)
            }
            Logger.tip.info(category: "TIP", message: "Check counter with newest account")
        }
        guard let pinToken = AppGroupKeychain.pinToken else {
            throw Error.missingPINToken
        }
        let watcher = try await TIPIdentityManager.watcher(pinToken: pinToken)
        Logger.tip.info(category: "TIP", message: "Watcher ready")
#if DEBUG
        try await MainActor.run {
            if TIPDiagnostic.failCounterWatchOnce {
                TIPDiagnostic.failCounterWatchOnce = false
                throw AFError.sessionTaskFailed(error: URLError(.badServerResponse))
            }
        }
#endif
        let counters = try await TIPNode.watch(watcher: watcher, timeoutInterval: timeoutInterval)
        if counters.isEmpty {
            Logger.tip.info(category: "TIP", message: "Empty counter watched")
            return nil
        } else {
            Logger.tip.info(category: "TIP", message: "Counters ready")
        }
        if counters.count != TIPConfig.current.signers.count {
            Logger.tip.warn(category: "TIP", message: "Watch count: \(counters.count), node count: \(TIPConfig.current.signers.count)")
        }
        let groups = counters.reduce(into: [UInt64: [TIPNode.Counter]]()) { (result, counter) in
            var counters = result[counter.value] ?? []
            counters.append(counter)
            result[counter.value] = counters
        }
        if groups.count <= 1 {
            let nodeCounter = counters[0].value
            if nodeCounter == account.tipCounter {
                return nil
            } else if nodeCounter < account.tipCounter {
                throw Error.tipCounterExceedsNodeCounter
            } else {
                return InterruptionContext(account: account,
                                           situation: .pendingUpdate,
                                           maxNodeCounter: nodeCounter)
            }
        } else if groups.count == 2 {
            let maxCounter = groups.keys.max()!
            let failedNodes = groups[groups.keys.min()!]!
            return InterruptionContext(account: account,
                                       situation: .pendingSign(failedNodes.map(\.signer)),
                                       maxNodeCounter: maxCounter)
        } else {
            throw Error.invalidCounterGroups
        }
    }
    
}

extension TIP {
    
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
        guard let privSeed = SHA3_256.hash(data: tipPriv) else {
            throw Error.hashTIPPrivToPrivSeed
        }
        let privateKey = try Ed25519PrivateKey(rawRepresentation: privSeed)
        let sig = try privateKey.signature(for: target)
        let pinData = sig
            + UInt64(Date().timeIntervalSince1970).data(endianness: .little)
            + pinIterator().data(endianness: .little)
        let based = try AESCryptor.encrypt(pinData, with: pinToken).base64RawURLEncodedString()
        return based
    }
    
    // TODO: Revert this function to internal after dependencies are migrated to SPM
    public static func getOrRecoverTIPPriv(pin: String, pinToken: Data) async throws -> Data {
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        let tipPriv: Data
        if let savedTIPPriv = AppGroupKeychain.tipPriv {
            Logger.tip.info(category: "TIP", message: "Using saved priv")
            let aesKey = try await getAESKey(pinData: pinData, pinToken: pinToken)
            guard let tipPrivKey = SHA3_256.hash(data: aesKey + pinData) else {
                throw Error.unableToHashTIPPrivKey
            }
            return try AESCryptor.decrypt(savedTIPPriv, with: tipPrivKey)
        } else {
            Logger.tip.info(category: "TIP", message: "Using new created priv")
            return try await createTIPPriv(pin: pin,
                                           failedSigners: [],
                                           legacyPIN: nil,
                                           forRecover: true,
                                           progressHandler: nil)
        }
    }
    
    static func pinIterator() -> UInt64 {
        var iterator: UInt64 = 0
        PropertiesDAO.shared.updateValue(forKey: .iterator, type: UInt64.self) { databaseValue in
            let userDefaultsValue = AppGroupUserDefaults.Crypto.iterator
            if let databaseValue = databaseValue {
                if databaseValue != userDefaultsValue {
                    Logger.tip.warn(category: "TIP", message: "database: \(databaseValue), defaults: \(userDefaultsValue)")
                }
                iterator = max(databaseValue, userDefaultsValue)
            } else {
                iterator = userDefaultsValue
                Logger.tip.info(category: "TIP", message: "Iterator initialized to \(userDefaultsValue)")
            }
            let nextIterator = iterator + 1
            AppGroupUserDefaults.Crypto.iterator = nextIterator
            return nextIterator
        }
        Logger.tip.info(category: "TIP", message: "Encrypt with it: \(iterator)")
        return iterator
    }
    
    static func ephemeralSeed(pinToken: Data) async throws -> Data {
        if let seed = AppGroupKeychain.ephemeralSeed {
            Logger.tip.info(category: "TIP", message: "Using saved ephemeral")
            return seed
        } else {
            let ephemerals = try await TIPAPI.ephemerals()
            if let newest = ephemerals.max(by: { $0.createdAt < $1.createdAt }), let decoded = Data(base64URLEncoded: newest.seed) {
                let seed = try AESCryptor.decrypt(decoded, with: pinToken)
                try await TIPAPI.updateEphemeral(base64URLEncoded: newest.seed)
                AppGroupKeychain.ephemeralSeed = seed
                Logger.tip.info(category: "TIP", message: "Using retrieved ephemeral")
                return seed
            } else if let seed = Data(withNumberOfSecuredRandomBytes: 32) {
                let encrypted = try AESCryptor.encrypt(seed, with: pinToken)
                let encoded = encrypted.base64RawURLEncodedString()
                try await TIPAPI.updateEphemeral(base64URLEncoded: encoded)
                AppGroupKeychain.ephemeralSeed = seed
                Logger.tip.info(category: "TIP", message: "Using updated ephemeral")
                return seed
            } else {
                throw Error.unableToGenerateSecuredRandom
            }
        }
    }
    
}

extension TIP {
    
    private static func encryptAndSaveTIPPriv(pinData: Data, aggSig: Data, aesKey: Data) throws {
        guard let key = SHA3_256.hash(data: aesKey + pinData) else {
            throw Error.generateTIPPrivKey
        }
        let tipPriv = try AESCryptor.encrypt(aggSig, with: key)
        AppGroupKeychain.tipPriv = tipPriv
    }
    
    private static func generateAESKey(pinData: Data, pinToken: Data) async throws -> Data {
        guard let sessionPriv = AppGroupKeychain.sessionSecret else {
            throw Error.missingSessionSecret
        }
        
        guard let stSeed = SHA3_256.hash(data: sessionPriv + pinData) else {
            throw Error.generateSTSeed
        }
        let stPriv = try Ed25519PrivateKey(rawRepresentation: stSeed)
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
        let stPriv = try Ed25519PrivateKey(rawRepresentation: stSeed)
        let timestamp = UInt64(Date().timeIntervalSince1970) * UInt64(NSEC_PER_SEC)
        
        let sigBase64 = try sign(timestamp: timestamp, with: stPriv)
        let request = TIPSecretReadRequest(signature: sigBase64, timestamp: timestamp)
        do {
            let seed = try await TIPAPI.readSecret(request: request).seed
            return try AESCryptor.decrypt(seed, with: pinToken)
        } catch {
            if case DecodingError.dataCorrupted = error {
                AppGroupKeychain.tipPriv = nil
                Logger.tip.warn(category: "TIP", message: "TIP Priv is removed due to invalid secret")
            }
            throw error
        }
    }
    
    private static func sign(timestamp: UInt64, with key: Ed25519PrivateKey) throws -> String {
        let body = try TIPBody.verify(timestamp: timestamp)
        let signature = try key.signature(for: body)
        return signature.base64RawURLEncodedString()
    }
    
}
