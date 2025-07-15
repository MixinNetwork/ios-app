import Foundation
import CryptoKit
import WalletConnectUtils

enum P2PKH {
    
    static func address(of publicKey: Data) -> String {
        let hash = RIPEMD160.hash(sha256(publicKey))
        let prefixedHash = Data(repeating: 0x00, count: 1) + hash
        let checksum = sha256(sha256(prefixedHash))[..<4]
        let address = Data(prefixedHash + checksum)
        return Base58.encode(address)
    }
    
    @inline(__always)
    private static func sha256(_ input: Data) -> Data {
        Data(SHA256.hash(data: input))
    }
    
}
