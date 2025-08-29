import Foundation
import XKCP_SimpleFIPS202
import secp256k1
import ReownWalletKit

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
        Keccak256.hash(data: data) ?? Data()
    }
    
}

extension Web3CryptoProvider {
    
    private enum Keccak256 {
        
        private static let outputCount = 32
        
        public static func hash(data: Data) -> Data? {
            let output = malloc(outputCount)!
            
            var hasher = Keccak_HashInstance()
            var result = HashReturn(0)
            Keccak_HashInitialize(&hasher, 1088, 512, 256, 0x01)
            
            result = data.withUnsafeUInt8Pointer { input in
                Keccak_HashUpdate(&hasher, input, data.count * 8)
            }
            guard result.rawValue == 0 else {
                free(output)
                return nil
            }
            
            result = Keccak_HashFinal(&hasher, output)
            guard result.rawValue == 0 else {
                free(output)
                return nil
            }
            
            return Data(bytesNoCopy: output, count: outputCount, deallocator: .free)
        }
        
    }
    
}
