import Foundation
import CryptoSwift
import web3
import Web3Wallet

struct Web3CryptoProvider: CryptoProvider {
    
    enum Error: Swift.Error {
        case hexDecoding
    }
    
    func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
        let key = try web3.KeyUtil.recoverPublicKey(message: message, signature: signature.serialized)
        if let data = Data(hex: key) {
            return data
        } else {
            throw Error.hexDecoding
        }
    }
    
    func keccak256(_ data: Data) -> Data {
        let digest = SHA3(variant: .keccak256)
        let hash = digest.calculate(for: [UInt8](data))
        return Data(hash)
    }
    
}
