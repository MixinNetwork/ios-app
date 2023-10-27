import Foundation

enum Argon2i {
    
    struct Error: Swift.Error {
        let code: Argon2_ErrorCodes.RawValue
    }
    
    static func hash(
        timeCost: UInt32 = 4,
        memoryCost: UInt32 = 1024,
        parallelism: UInt32 = 2,
        password: Data,
        salt: Data,
        hashCount: Int = 32
    ) throws -> Data {
        var hash = Data(count: hashCount)
        let result = password.withUnsafeBytes { password in
            salt.withUnsafeBytes { salt in
                hash.withUnsafeMutableBytes { hash in
                    argon2i_hash_raw(timeCost,
                                     memoryCost,
                                     parallelism,
                                     password.baseAddress,
                                     password.count,
                                     salt.baseAddress,
                                     salt.count,
                                     hash.baseAddress,
                                     hash.count)
                }
            }
        }
        if result == ARGON2_OK.rawValue {
            return hash
        } else {
            throw Error(code: result)
        }
    }
    
}
