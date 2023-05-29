import Foundation
import CryptoSwift
import web3
import Auth

final class Web3SignerFactory: SignerFactory {
    
    func createEthereumSigner() -> EthereumSigner {
        Web3Signer()
    }
    
}

fileprivate final class Web3Signer: EthereumSigner {
    
    enum Error: Swift.Error {
        case hexDecoding
    }
    
    func sign(message: Data, with key: Data) throws -> EthereumSignature {
        let storage = InPlaceKeyStorage(raw: key)
        let account = try EthereumAccount(keyStorage: storage)
        let signature = try account.sign(message: message)
        return EthereumSignature(serialized: signature)
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
