import Foundation
import XKCP_FIPS202
import WalletConnectSigner

struct Web3CryptoProvider: CryptoProvider {
    
    func recoverPubKey(
        signature: EthereumSignature,
        message: Data,
    ) throws(EVM.Error) -> Data {
        guard signature.r.count == 32, signature.s.count == 32, signature.v <= 1 else {
            throw .invalidSignature
        }
        let publicKey = try EVM.recoverPublicKey(
            hash: keccak256(message),
            signature: signature.serialized,
        )
        // WalletConnect hashes the raw X and Y coordinates to derive the address.
        return Data(publicKey.dropFirst())
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
            var result = Keccak_HashInitialize(&hasher, 1088, 512, 256, 0x01)
            guard result.rawValue == 0 else {
                free(output)
                return nil
            }
            
            result = data.withUnsafeBytes { buffer in
                Keccak_HashUpdate(&hasher, buffer.baseAddress, buffer.count * 8)
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
