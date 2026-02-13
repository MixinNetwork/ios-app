import Foundation
import CryptoKit
import Alamofire

public enum TIP {
    
    public struct InterruptionContext {
        
        public enum Situation {
            case pendingUpdate
            case pendingSign(_ failedSigners: [TIPSigner])
        }
        
        public let action: Action
        public let situation: Situation
        public let accountTIPCounter: UInt64
        public let maxNodeCounter: UInt64
        
#if DEBUG
        public init(action: Action, situation: Situation, accountTIPCounter: UInt64, maxNodeCounter: UInt64) {
            self.action = action
            self.situation = situation
            self.accountTIPCounter = accountTIPCounter
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
            self.accountTIPCounter = account.tipCounter
            self.maxNodeCounter = maxNodeCounter
        }
        
    }
    
    @frozen public enum Action {
        case create
        case change
        case migrate
    }
    
    @frozen public enum Progress {
        case creating
        case connecting
        case synchronizing(Float)
    }
    
    public enum Error: Swift.Error, CustomNSError {
        
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
        case invalidUserID
        case missingAccountSalt
        case noSalt
        case invalidSize([String: String])
        case missingMnemonics
        #if DEBUG
        case mock
        #endif
        
        public var errorUserInfo: [String : Any] {
            switch self {
            case let .invalidSize(sizes):
                sizes
            default:
                [:]
            }
        }
        
    }
    
    struct RegisterSafeError: Swift.Error, CustomNSError {
        
        let underlying: Swift.Error
        let step1: String
        let step2: String
        
        var errorUserInfo: [String : Any] {
            ["underlying": "\(underlying)", "step1": step1, "step2": step2]
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
    ) async throws -> (tipPriv: Data, account: Account?) {
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
        let (aggSig, _) = try await TIPNode.sign(identityPriv: identityPriv,
                                                 ephemeral: ephemeralSeed,
                                                 watcher: watcher,
                                                 assigneePriv: nil,
                                                 failedSigners: failedSigners,
                                                 forRecover: false,
                                                 progressHandler: progressHandler)
        Logger.tip.info(category: "TIP", message: "aggSig ready")
        guard let tipPriv = SHA3_256.hash(data: aggSig) else {
            throw Error.hashAggSigToPrivSeed
        }
        let priv = try Ed25519PrivateKey(rawRepresentation: tipPriv)
        let pub = priv.publicKey.rawRepresentation
        if let localPub = LoginManager.shared.account?.tipKey, !localPub.isEmpty, pub != localPub {
            throw Error.incorrectPIN
        }
        
        let aesKey = try await generateAESKey(pinData: pinData, pinToken: pinToken)
        Logger.tip.info(category: "TIP", message: "AES key ready")
        if forRecover {
            Logger.tip.info(category: "TIP", message: "Recovering")
            try await encryptAndSaveTIPPriv(pinData: pinData, tipPriv: tipPriv, aesKey: aesKey)
            return (tipPriv: tipPriv, account: nil)
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
        let request = PINRequest(pin: new, oldPIN: oldEncryptedPIN, salt: nil, oldSalt: nil, timestamp: nil)
#if DEBUG
        try await MainActor.run {
            if TIPDiagnostic.failPINUpdateServerSideOnce {
                TIPDiagnostic.failPINUpdateServerSideOnce = false
                throw Error.mock
            }
        }
#endif
        Logger.tip.info(category: "TIP", message: "Will update PIN")
        let account = try await AccountAPI.updatePIN(request: request)
#if DEBUG
        try await MainActor.run {
            if TIPDiagnostic.failPINUpdateClientSideOnce {
                TIPDiagnostic.failPINUpdateClientSideOnce = false
                throw Error.mock
            }
            if TIPDiagnostic.crashAfterUpdatePIN {
                abort()
            }
        }
#endif
        LoginManager.shared.setAccount(account)
        Logger.tip.info(category: "TIP", message: "Local account is updated with tip_counter: \(account.tipCounter)")
        
        try encryptAndSaveTIPPriv(pinData: pinData, tipPriv: tipPriv, aesKey: aesKey)
        Logger.tip.info(category: "TIP", message: "TIP Priv is saved")
        return (tipPriv: tipPriv, account: account)
    }
    
    @discardableResult
    public static func updateTIPPriv(
        oldPIN: String,
        newPIN: String,
        isCounterBalanced: Bool,
        failedSigners: [TIPSigner],
        progressHandler: (@MainActor (Progress) -> Void)?
    ) async throws -> Account {
        Logger.tip.info(category: "TIP", message: "Update priv with oldPIN: \(oldPIN != nil), failedSigners: \(failedSigners.map(\.index))")
        guard let oldPINData = oldPIN.data(using: .utf8) else {
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
        Logger.tip.info(category: "TIP", message: "Ephemeral seed ready")
        
        // 1. Change PIN, requires assignee
        // 2. Change PIN interrupted, failure in some of the nodes, requires assignee
        // 3. Change PIN interrupted, all node succeed, does not requires assignee
        let identityPriv: Data
        let watcher: Data
        let assigneePriv: Data?
        if !isCounterBalanced && failedSigners.isEmpty {
            (identityPriv, watcher) = try await TIPIdentityManager.identityPair(pinData: newPINData, pinToken: pinToken)
            Logger.tip.info(category: "TIP", message: "Identity pair ready")
            assigneePriv = nil
            Logger.tip.info(category: "TIP", message: "No assigneePriv needed")
        } else {
            (identityPriv, watcher) = try await TIPIdentityManager.identityPair(pinData: oldPINData, pinToken: pinToken)
            Logger.tip.info(category: "TIP", message: "Identity pair ready")
            assigneePriv = try await TIPIdentityManager.identityPair(pinData: newPINData, pinToken: pinToken).priv
            Logger.tip.info(category: "TIP", message: "assigneePriv ready")
        }
        
        await progressHandler?(.connecting)
        let (aggSig, nodeCounter) = try await TIPNode.sign(identityPriv: identityPriv,
                                                           ephemeral: ephemeralSeed,
                                                           watcher: watcher,
                                                           assigneePriv: assigneePriv,
                                                           failedSigners: failedSigners,
                                                           forRecover: false,
                                                           progressHandler: progressHandler)
        Logger.tip.info(category: "TIP", message: "aggSig ready")
        guard let tipPriv = SHA3_256.hash(data: aggSig) else {
            throw Error.hashAggSigToPrivSeed
        }
        let aesKey = try await generateAESKey(pinData: newPINData, pinToken: pinToken)
        Logger.tip.info(category: "TIP", message: "AES key ready")
        let privateKey = try Ed25519PrivateKey(rawRepresentation: tipPriv)
        let pub = privateKey.publicKey.rawRepresentation
        guard let accountBeforeUpdate = LoginManager.shared.account else {
            throw Error.noAccount
        }
        let accountCounter = accountBeforeUpdate.tipCounter
        let body = try TIPBody.verify(timestamp: accountCounter)
        let oldPIN = try encryptTIPPIN(tipPriv: tipPriv, target: body)
        let newEncryptPIN = try encryptPIN(key: pinToken, code: pub + (accountCounter + 1).data(endianness: .big))
        
        let pinTokenEncryptedSalt: (old: String, new: String)?
        let encryptedSaltToSave: Data?
        if accountBeforeUpdate.hasSafe {
            let newSaltKey = try saltAESKey(pin: newPINData, tipPriv: tipPriv)
            if accountBeforeUpdate.isAnonymous {
                Logger.tip.info(category: "TIP", message: "Update for anonymous user")
                guard let accountSalt = accountBeforeUpdate.salt else {
                    throw Error.missingAccountSalt
                }
                let placeholdingSalt = Data(count: MixinMnemonics.EntropyCount.default.rawValue)
                let newEncryptedPlaceholdingSalt = try AESCryptor.encrypt(placeholdingSalt, with: newSaltKey)
                pinTokenEncryptedSalt = (
                    old: accountSalt,
                    new: try AESCryptor.encrypt(newEncryptedPlaceholdingSalt, with: pinToken).base64RawURLEncodedString()
                )
                encryptedSaltToSave = newEncryptedPlaceholdingSalt
            } else {
                Logger.tip.info(category: "TIP", message: "Update for phone user")
                let oldEncryptedSalt = try await custodialEncryptedSalt()
                let oldSaltKey = try saltAESKey(pin: oldPINData, tipPriv: tipPriv)
                let salt = try AESCryptor.decrypt(oldEncryptedSalt, with: oldSaltKey)
                let newEncryptedSalt = try AESCryptor.encrypt(salt, with: newSaltKey)
#if DEBUG
                Logger.tip.info(category: "TIP", message: "Plain salt: \(salt.hexEncodedString())")
#endif
                pinTokenEncryptedSalt = (
                    old: try AESCryptor.encrypt(oldEncryptedSalt, with: pinToken).base64RawURLEncodedString(),
                    new: try AESCryptor.encrypt(newEncryptedSalt, with: pinToken).base64RawURLEncodedString()
                )
                encryptedSaltToSave = newEncryptedSalt
            }
#if DEBUG
            Logger.tip.info(category: "TIP", message: "Update with newKey: \(newSaltKey.base64RawURLEncodedString()), pinTokenEncrypted: \(pinTokenEncryptedSalt)")
#endif
        } else {
            Logger.tip.info(category: "TIP", message: "Account not registered to safe")
            pinTokenEncryptedSalt = nil
            encryptedSaltToSave = nil
        }
        
        let request = PINRequest(pin: newEncryptPIN,
                                 oldPIN: oldPIN,
                                 salt: pinTokenEncryptedSalt?.new,
                                 oldSalt: pinTokenEncryptedSalt?.old,
                                 timestamp: nil)
        AppGroupKeychain.encryptedTIPPriv = nil
        AppGroupKeychain.encryptedSalt = nil
        Logger.tip.info(category: "TIP", message: "TIP Priv/Salt is removed")
#if DEBUG
        try await MainActor.run {
            if TIPDiagnostic.failPINUpdateServerSideOnce {
                TIPDiagnostic.failPINUpdateServerSideOnce = false
                throw Error.mock
            }
        }
#endif
        Logger.tip.info(category: "TIP", message: "Will update PIN")
        let account = try await AccountAPI.updatePIN(request: request)
#if DEBUG
        try await MainActor.run {
            if TIPDiagnostic.failPINUpdateClientSideOnce {
                TIPDiagnostic.failPINUpdateClientSideOnce = false
                throw Error.mock
            }
            if TIPDiagnostic.crashAfterUpdatePIN {
                abort()
            }
        }
#endif
        LoginManager.shared.setAccount(account)
        Logger.tip.info(category: "TIP", message: "Local account is updated with tip_counter: \(account.tipCounter)")
        try encryptAndSaveTIPPriv(pinData: newPINData, tipPriv: tipPriv, aesKey: aesKey)
        Logger.tip.info(category: "TIP", message: "TIP Priv is saved")
        AppGroupKeychain.encryptedSalt = encryptedSaltToSave
        Logger.tip.info(category: "TIP", message: "Encrypted salt(\(encryptedSaltToSave == nil)) is saved")
        return account
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
                throw Error.mock
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
    
    public static func getOrRecoverTIPPriv(pin: String) async throws -> Data {
        let pinToken: Data
        if let token = AppGroupKeychain.pinToken {
            pinToken = token
        } else if let encoded = AppGroupUserDefaults.Account.pinToken, let token = Data(base64Encoded: encoded) {
            pinToken = token
        } else {
            throw Error.missingPINToken
        }
        return try await getOrRecoverTIPPriv(pin: pin, pinToken: pinToken)
    }
    
    public static func registerToSafeIfNeeded(account: Account?, pin: String) async throws {
        Logger.tip.info(category: "TIP", message: "Register to safe")
        let account = if let account {
            account
        } else {
            try await AccountAPI.me()
        }
        guard !account.hasSafe else {
            Logger.tip.info(category: "TIP", message: "Already safe")
            return
        }
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        guard let pinToken = AppGroupKeychain.pinToken else {
            throw Error.missingPINToken
        }
        
        guard
            let userIDData = account.userID.data(using: .utf8),
            let userIDHash = SHA3_256.hash(data: userIDData)
        else {
            throw Error.invalidUserID
        }
        
        var step1 = "PIN: \(pin.count)"
        var step2 = ""
        do {
            let tipPriv = try await getOrRecoverTIPPriv(pin: pin)
            step1 += ", TIP Priv: \(tipPriv.count)"
            
            let mnemonics: MixinMnemonics
            if let entropy = AppGroupKeychain.mnemonics {
                step1 += ", Using saved entropy"
                mnemonics = try MixinMnemonics(entropy: entropy)
            } else {
                if account.isAnonymous {
                    step1 += ", Missing entropy"
                    // No phone, no mnemonics, a wasted account
                    throw Error.missingMnemonics
                } else {
                    // Sign up with phone, generate a random entropy
                    step1 += ", Using random entropy"
                    mnemonics = try .random()
                    // Save mnemonics to keychain, in case of upcoming request failure
                    AppGroupKeychain.mnemonics = mnemonics.entropy
                }
            }
            let masterKey = try MasterKey.key(from: mnemonics)
            
            let salt = if account.isAnonymous {
                Data(count: MixinMnemonics.EntropyCount.default.rawValue)
            } else {
                mnemonics.entropy
            }
            let saltAESKey = try saltAESKey(pin: pinData, tipPriv: tipPriv)
            step1 += ", salt: \(salt.count), saltAESKey: \(saltAESKey.count)"
            
            let encryptedSalt = try AESCryptor.encrypt(salt, with: saltAESKey)
            step1 += ", encryptedSalt: \(encryptedSalt.count)"
            
            let pinTokenEncryptedSalt = try AESCryptor.encrypt(encryptedSalt, with: pinToken)
            step1 += ", ptEncryptedSalt: \(pinTokenEncryptedSalt.count)"
            
            let spendSeed = try spendPriv(salt: mnemonics.entropy, tipPriv: tipPriv)
            step1 += ", spendSeed: \(spendSeed.count)"
            
            let keyPair = try Curve25519.Signing.PrivateKey(rawRepresentation: spendSeed)
            step2 += "KeyPair Ready"
            
            let pkHex = keyPair.publicKey.rawRepresentation.hexEncodedString()
            step2 = ", pkHex: \(pkHex.count)"
            
            let registerSignature = try keyPair.signature(for: userIDHash)
            step2 += ", signature: \(registerSignature.count)"
            
            let body = try TIPBody.registerSequencer(userID: account.userID, publicKey: pkHex)
            let pin = try encryptTIPPIN(tipPriv: tipPriv, target: body)
            step2 += ", pin ready"
            
            let account = try await SafeAPI.register(
                publicKey: pkHex,
                signature: registerSignature.base64RawURLEncodedString(),
                pin: pin,
                salt: pinTokenEncryptedSalt.base64RawURLEncodedString(),
                masterPublicKey: masterKey.publicKey.rawRepresentation.hexEncodedString(),
                masterSignature: try masterKey.signature(for: userIDData).hexEncodedString()
            )
            LoginManager.shared.setAccount(account)
            Logger.tip.info(category: "TIP", message: "Local account is updated with registration")
            if !account.isAnonymous {
                AppGroupKeychain.mnemonics = nil
                Logger.tip.info(category: "TIP", message: "AppGroupKeychain.mnemonics cleared")
            }
            AppGroupKeychain.encryptedSalt = encryptedSalt
            Logger.tip.info(category: "TIP", message: "Encrypted salt is saved")
        } catch {
            Logger.tip.error(category: "TIP", message: "Error: \(error), step1: \(step1), step2: \(step2)")
            let registerError = RegisterSafeError(underlying: error, step1: step1, step2: step2)
            reporter.report(error: registerError)
            throw error
        }
    }
    
    public static func spendPriv(pin: String) async throws -> Data {
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        let tipPriv = try await getOrRecoverTIPPriv(pin: pin)
        let salt = try await salt(pinData: pinData, tipPriv: tipPriv)
        return try Argon2i.hash(password: tipPriv, salt: salt)
    }
    
    public static func salt(pin: String) async throws -> Data {
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        let tipPriv = try await TIP.getOrRecoverTIPPriv(pin: pin)
        return try await salt(pinData: pinData, tipPriv: tipPriv)
    }
    
    public static func encryptedSalt(pin: String) async throws -> Data {
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        if let salt = AppGroupKeychain.mnemonics {
            let tipPriv = try await TIP.getOrRecoverTIPPriv(pin: pin)
            let key = try saltAESKey(pin: pinData, tipPriv: tipPriv)
            return try AESCryptor.encrypt(salt, with: key)
        } else if let account = LoginManager.shared.account {
            if account.isAnonymous {
                throw Error.noSalt
            } else {
                return try await custodialEncryptedSalt()
            }
        } else {
            throw Error.noAccount
        }
    }
    
    // This function is used to retrieve the custodial encrypted salt
    // For accounts with phone number added, calling it will return the actual value
    // For mnemonic-based accounts, calling it will return an encrypted placeholder
    public static func custodialEncryptedSalt() async throws -> Data {
        if let salt = AppGroupKeychain.encryptedSalt {
            Logger.tip.info(category: "TIP", message: "Using saved encrypted salt")
            return salt
        } else {
            let account = try await AccountAPI.me()
            LoginManager.shared.setAccount(account, updateUserTable: false)
            guard let accountSalt = account.salt, let pinTokenEncryptedSalt = Data(base64URLEncoded: accountSalt) else {
                throw Error.missingAccountSalt
            }
            guard let pinToken = AppGroupKeychain.pinToken else {
                throw Error.missingPINToken
            }
            let encryptedSalt = try AESCryptor.decrypt(pinTokenEncryptedSalt, with: pinToken)
            AppGroupKeychain.encryptedSalt = encryptedSalt
            Logger.tip.info(category: "TIP", message: "Encrypted salt is saved")
            return encryptedSalt
        }
    }
    
    // This function is used to retrieve the custodial salt
    // For accounts with phone number added, calling it will return the actual value
    // For mnemonic-based accounts, calling it will return the placeholder
    public static func custodialSalt(pin: String) async throws -> Data {
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        let encryptedSalt = try await custodialEncryptedSalt()
        let tipPriv = try await TIP.getOrRecoverTIPPriv(pin: pin)
        let key = try saltAESKey(pin: pinData, tipPriv: tipPriv)
        return try AESCryptor.decrypt(encryptedSalt, with: key)
    }
    
    private static func salt(pinData: Data, tipPriv: Data) async throws -> Data {
        if let salt = AppGroupKeychain.mnemonics {
            return salt
        } else if let account = LoginManager.shared.account {
            if account.isAnonymous {
                throw Error.noSalt
            } else {
                let encryptedSalt = try await custodialEncryptedSalt()
                let key = try saltAESKey(pin: pinData, tipPriv: tipPriv)
                return try AESCryptor.decrypt(encryptedSalt, with: key)
            }
        } else {
            throw Error.noAccount
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
        let privateKey = try Ed25519PrivateKey(rawRepresentation: tipPriv)
        let sig = try privateKey.signature(for: target)
        let pinData = sig
            + UInt64(Date().timeIntervalSince1970).data(endianness: .little)
            + pinIterator().data(endianness: .little)
        let based = try AESCryptor.encrypt(pinData, with: pinToken).base64RawURLEncodedString()
        return based
    }
    
    private static func getOrRecoverTIPPriv(pin: String, pinToken: Data) async throws -> Data {
        guard let pinData = pin.data(using: .utf8) else {
            throw Error.invalidPIN
        }
        if let savedTIPPriv = AppGroupKeychain.encryptedTIPPriv {
            Logger.tip.info(category: "TIP", message: "Using saved priv: \(savedTIPPriv.count)")
            let aesKey = try await getAESKey(pinData: pinData, pinToken: pinToken)
            Logger.tip.info(category: "TIP", message: "TIP Priv AES key ready: \(aesKey.count)")
            guard let tipPrivKey = SHA3_256.hash(data: aesKey + pinData) else {
                throw Error.unableToHashTIPPrivKey
            }
            let decrypted = try AESCryptor.decrypt(savedTIPPriv, with: tipPrivKey)
            switch decrypted.count {
            case 32:
                return decrypted
            case 64:
                // In history versions aggSig(64 bytes) was saved in Keychain instead of TIP Priv(32 bytes)
                // Migrate to TIP priv once found
                guard let tipPriv = SHA3_256.hash(data: decrypted) else {
                    throw Error.hashAggSigToPrivSeed
                }
                let encrypted = try AESCryptor.encrypt(tipPriv, with: tipPrivKey)
                AppGroupKeychain.encryptedTIPPriv = encrypted
                Logger.tip.info(category: "TIP", message: "TIP Priv is migrated from: \(decrypted.count), to: \(tipPriv.count)")
                return tipPriv
            default:
                AppGroupKeychain.encryptedTIPPriv = nil
                let sizeInfo = [
                    "keychain": "\(savedTIPPriv.count)",
                    "key": "\(tipPrivKey.count)",
                    "decrypted": "\(decrypted.count)"
                ]
                Logger.tip.error(category: "TIP", message: "Invalid size", userInfo: sizeInfo)
                reporter.report(error: Error.invalidSize(sizeInfo))
            }
        }
        Logger.tip.info(category: "TIP", message: "Using new created priv")
        let (tipPriv, _) = try await createTIPPriv(
            pin: pin,
            failedSigners: [],
            legacyPIN: nil,
            forRecover: true,
            progressHandler: nil
        )
        return tipPriv
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
    
    private static func encryptAndSaveTIPPriv(pinData: Data, tipPriv: Data, aesKey: Data) throws {
        guard let key = SHA3_256.hash(data: aesKey + pinData) else {
            throw Error.generateTIPPrivKey
        }
        let encryptedTIPPriv = try AESCryptor.encrypt(tipPriv, with: key)
        AppGroupKeychain.encryptedTIPPriv = encryptedTIPPriv
        Logger.tip.info(category: "TIP", message: "Saved TIP Priv: \(encryptedTIPPriv.count)")
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
                AppGroupKeychain.encryptedTIPPriv = nil
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
    
    private static func spendPriv(salt: Data, tipPriv: Data) throws -> Data {
        try Argon2i.hash(password: tipPriv, salt: salt)
    }
    
    private static func saltAESKey(pin: Data, tipPriv: Data) throws -> Data {
        try Argon2i.hash(password: pin, salt: tipPriv)
    }
    
}
