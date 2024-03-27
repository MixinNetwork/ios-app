import Foundation
import CryptoSwift
import secp256k1
import Web3Wallet

struct Web3CryptoProvider: CryptoProvider {
    
    enum Error: Swift.Error {
        case hexDecoding
    }
    
    func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
        let signature = try secp256k1.Recovery.ECDSASignature(dataRepresentation: signature.serialized)
        let publicKey = try secp256k1.Recovery.PublicKey(message, signature: signature, format: .uncompressed)
        return publicKey.dataRepresentation
    }
    
    func keccak256(_ data: Data) -> Data {
        let digest = SHA3(variant: .keccak256)
        let hash = digest.calculate(for: [UInt8](data))
        return Data(hash)
    }
    
}
