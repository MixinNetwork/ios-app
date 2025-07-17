import Foundation
import CryptoKit

struct EncryptedBIP39Mnemonics {
    
    enum EncryptionError: Error {
        case invalidLayout
    }
    
    let data: Data
    
    // Only provide `nonce` when testing
    init(mnemonics: BIP39Mnemonics, key: Data, nonce: AES.GCM.Nonce? = nil) throws {
        let key = SymmetricKey(data: key)
        let box = try AES.GCM.seal(mnemonics.entropy, using: key, nonce: nonce)
        guard let data = box.combined else {
            throw EncryptionError.invalidLayout
        }
        self.data = data
    }
    
    func decrypt(with key: Data) throws -> BIP39Mnemonics {
        let box = try AES.GCM.SealedBox(combined: data)
        let key = SymmetricKey(data: key)
        let entropy = try AES.GCM.open(box, using: key)
        return try BIP39Mnemonics(entropy: entropy)
    }
    
}

extension EncryptedBIP39Mnemonics: Codable {
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.data = try container.decode(Data.self)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
    
}
