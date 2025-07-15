import Foundation
import CryptoKit
import BigInt
import secp256k1
import MixinServices

// https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
// https://github.com/satoshilabs/slips/blob/master/slip-0010.md

struct ExtendedKey {
    
    enum Curve {
        case secp256k1
        case ed25519
    }
    
    let key: Data
    let chainCode: Data
    
    init(seed: Data, curve: Curve) {
        let (key, chainCode) = switch curve {
        case .secp256k1:
            Self.hmacSHA512(seed, key: "Bitcoin seed".data(using: .utf8)!)
        case .ed25519:
            Self.hmacSHA512(seed, key: "ed25519 seed".data(using: .utf8)!)
        }
        self.init(key: key, chainCode: chainCode)
    }
    
    private init(key: Data, chainCode: Data) {
        self.key = key
        self.chainCode = chainCode
    }
    
    static func hmacSHA512(_ plain: Data, key keyData: Data) -> (left: Data, right: Data) {
        let key = SymmetricKey(data: keyData)
        var hasher = HMAC<SHA512>(key: key)
        hasher.update(data: plain)
        let hash = Data(hasher.finalize())
        return (left: hash[..<32], right: hash[32...])
    }
    
}

// Secp256k1
extension ExtendedKey {
    
    enum Error: Swift.Error {
        case missingStorage
        case createContext
        case randomizeContext
        case verifyPrivateKey
        case createPublicKey
        case serializePublicKey
        case invalidIndex
        case invalidKI
    }
    
    enum Index {
        
        case normal(UInt32)
        case hardened(UInt32)
        
        var value: UInt32 {
            switch self {
            case .normal(let value):
                return value
            case .hardened(let value):
                return value | 0x80000000
            }
        }
        
    }
    
    func deriveUsingSecp256k1(path: DerivationPath) throws -> ExtendedKey {
        try path.indices.reduce(self) { key, index in
            try key.privateKeyUsingSecp256k1(index: index)
        }
    }
    
    func publicKey() throws -> Data {
        try Self.point(key)
    }
    
    private func privateKeyUsingSecp256k1(index: Index) throws -> ExtendedKey {
        let n = BigUInt("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141", radix: 16)!
        let il, ir: Data
        switch index {
        case .normal:
            let kPoint = try Self.point(key)
            let data = kPoint + index.value.data(endianness: .big)
            (il, ir) = Self.hmacSHA512(data, key: chainCode)
        case .hardened:
            let data = Data([0x00] + key + index.value.data(endianness: .big))
            (il, ir) = Self.hmacSHA512(data, key: chainCode)
        }
        let parse256IL = BigUInt(il)
        guard parse256IL < n else {
            throw Error.invalidIndex
        }
        let kPar = BigUInt(key)
        let ki = (parse256IL + kPar) % n
        guard !ki.isZero else {
            throw Error.invalidIndex
        }
        let kiData = ki.serialize()
        let key: Data
        if kiData.count < 32 {
            key = Data(repeating: 0, count: 32 - kiData.count) + kiData
        } else if kiData.count == 32 {
            key = kiData
        } else {
            throw Error.invalidKI
        }
        return ExtendedKey(key: key, chainCode: ir)
    }
    
    private static func point(_ data: Data) throws -> Data {
        let signAndVerify = UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)
        guard let ctx = secp256k1_context_create(signAndVerify) else {
            throw Error.createContext
        }
        defer {
            secp256k1_context_destroy(ctx)
        }
        
        guard
            let contextSeed = Data(withNumberOfSecuredRandomBytes: 32),
            contextSeed.withUnsafeUInt8Pointer({ secp256k1_context_randomize(ctx, $0) }) == 1
        else {
            throw Error.randomizeContext
        }
        
        return try data.withUnsafeUInt8Pointer { data in
            guard let data else {
                throw Error.missingStorage
            }
            guard secp256k1_ec_seckey_verify(ctx, data) == 1 else {
                throw Error.verifyPrivateKey
            }
            
            let publicKey = UnsafeMutablePointer<secp256k1_pubkey>.allocate(capacity: 1)
            defer {
                publicKey.deallocate()
            }
            guard secp256k1_ec_pubkey_create(ctx, publicKey, data) == 1 else {
                throw Error.createPublicKey
            }
            
            let compressed = UInt32(SECP256K1_EC_COMPRESSED)
            var outputLength = 33
            let output = malloc(outputLength)!
            guard secp256k1_ec_pubkey_serialize(ctx, output, &outputLength, publicKey, compressed) == 1 else {
                throw Error.serializePublicKey
            }
            return Data(bytesNoCopy: output, count: outputLength, deallocator: .free)
        }
    }
    
}

// ed25519
extension ExtendedKey {
    
    func deriveUsingEd25519(path: DerivationPath) -> ExtendedKey {
        path.indices.reduce(self) { key, index in
            key.privateKeyUsingEd25519(hardeningIndex: index.value)
        }
    }
    
    private func privateKeyUsingEd25519(hardeningIndex: UInt32) -> ExtendedKey {
        let index = (hardeningIndex | 0x80000000)
        let body = [0x00] + key + withUnsafeBytes(of: index.bigEndian, Data.init(_:))
        let hmacKey = SymmetricKey(data: chainCode)
        let hmacResult = HMAC<SHA512>.authenticationCode(for: body, using: hmacKey)
        let key = Data(hmacResult.prefix(32))
        let chainCode = Data(hmacResult.suffix(32))
        return ExtendedKey(key: key, chainCode: chainCode)
    }
    
}
