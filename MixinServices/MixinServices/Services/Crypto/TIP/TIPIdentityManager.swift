import Foundation
import SignalArgon2

enum TIPIdentityManager {
    
    enum Error: Swift.Error {
        case identitySeedHash
    }
    
    static func identityPair(pinData: Data, pinToken: Data) async throws -> (priv: Data, watcher: Data) {
        Logger.tip.info(category: "TIPIdentityManager", message: "Generating identity pair")
        let identitySeed = try await identitySeed(pinToken: pinToken)
        let identityPriv = try Argon2.hash(iterations: 4,
                                           memoryInKiB: 1024,
                                           threads: 2,
                                           password: pinData,
                                           salt: identitySeed,
                                           desiredLength: 32,
                                           variant: .i,
                                           version: .v13)
        let watcher = try watcher(pinToken: pinToken, identitySeed: identitySeed)
        return (identityPriv.raw, watcher)
    }
    
    static func watcher(pinToken: Data) async throws -> Data {
        let seed = try await identitySeed(pinToken: pinToken)
        return try await watcher(pinToken: pinToken, identitySeed: seed)
    }
    
    private static func identitySeed(pinToken: Data) async throws -> Data {
        let identity = try await TIPAPI.identity()
        return try AESCryptor.decrypt(identity.seed, with: pinToken)
    }
    
    private static func watcher(pinToken: Data, identitySeed: Data) throws -> Data {
        if let watcher = SHA3_256.hash(data: identitySeed) {
            return watcher
        } else {
            throw Error.identitySeedHash
        }
    }
    
}
