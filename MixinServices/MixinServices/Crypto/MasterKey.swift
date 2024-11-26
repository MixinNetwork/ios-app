import Foundation
import CryptoKit
import TIP

public enum MasterKey {
    
    private enum DerivationError: Error {
        case pbkdf2
        case mismatched
    }
    
    public static func key(from mnemonics: Mnemonics) throws -> Ed25519PrivateKey {
        let nativeMasterKey = try {
            let privateKeySeed = PBKDF2.derivation(
                password: mnemonics.bip39,
                salt: "mnemonic",
                pseudoRandomAlgorithm: .hmacSHA512,
                iterationCount: 2048,
                keyCount: 64
            )
            guard let privateKeySeed else {
                throw DerivationError.pbkdf2
            }
            let hmacKey = SymmetricKey(data: "Bitcoin seed".data(using: .utf8)!)
            let hmac = HMAC<SHA512>.authenticationCode(for: privateKeySeed, using: hmacKey)
            let masterKey = Data(hmac.prefix(32))
            return masterKey
        }()
        
        let goMasterKey = try {
            var error: NSError?
            let key = BlockchainMnemonicToMasterKey(mnemonics.bip39, &error)
            if let error {
                throw error
            }
            return Data(hexEncodedString: key)
        }()
        
        guard nativeMasterKey == goMasterKey else {
            throw DerivationError.mismatched
        }
        return try Ed25519PrivateKey(rawRepresentation: nativeMasterKey)
    }
    
}
