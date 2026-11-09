import Foundation
import CryptoKit
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
    
    init(seed: Data, curve: Curve) throws(Error) {
        let key: Data, chainCode: Data
        switch curve {
        case .secp256k1:
            var result = BitcoinExtendedPrivateKey()
            let status = seed.withUnsafeBytes { bytes in
                bitcoin_bip32_master_key(
                    bytes.bindMemory(to: UInt8.self).baseAddress,
                    bytes.count,
                    &result,
                )
            }
            guard status == BitcoinErrorCodeSuccess else {
                throw .sdk(Int32(status.rawValue))
            }
            key = withUnsafeBytes(of: result.key, Data.init(_:))
            chainCode = withUnsafeBytes(of: result.chain_code, Data.init(_:))
        case .ed25519:
            (key, chainCode) = Self.hmacSHA512(seed, key: "ed25519 seed".data(using: .utf8)!)
        }
        self.init(key: key, chainCode: chainCode)
    }
    
    private init(key: Data, chainCode: Data) {
        precondition(key.count == 32 && chainCode.count == 32)
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
        case sdk(Int32)
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
    
    func deriveUsingSecp256k1(path: DerivationPath) throws(Error) -> ExtendedKey {
        var input = BitcoinExtendedPrivateKey()
        _ = withUnsafeMutableBytes(of: &input.key) { key.copyBytes(to: $0) }
        _ = withUnsafeMutableBytes(of: &input.chain_code) { chainCode.copyBytes(to: $0) }
        var result = BitcoinExtendedPrivateKey()
        let status = path.indices.map(\.value).withUnsafeBufferPointer { indices in
            bitcoin_bip32_derive_key(&input, indices.baseAddress, indices.count, &result)
        }
        guard status == BitcoinErrorCodeSuccess else {
            throw .sdk(Int32(status.rawValue))
        }
        return ExtendedKey(
            key: withUnsafeBytes(of: result.key, Data.init(_:)),
            chainCode: withUnsafeBytes(of: result.chain_code, Data.init(_:)),
        )
    }
    
    func publicKey() throws(Error) -> Data {
        var result = BitcoinCompressedPublicKey()
        let status = key.withUnsafeBytes { bytes in
            bitcoin_compressed_public_key(
                bytes.bindMemory(to: UInt8.self).baseAddress,
                bytes.count,
                &result,
            )
        }
        guard status == BitcoinErrorCodeSuccess else {
            throw .sdk(Int32(status.rawValue))
        }
        return withUnsafeBytes(of: result.bytes, Data.init(_:))
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
