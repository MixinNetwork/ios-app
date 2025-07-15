import Foundation
import MixinServices

struct EncryptedBIP39Mnemonics {
    
    private let data: Data
    
    init(mnemonics: BIP39Mnemonics, key: Data) throws {
        self.data = try AESCryptor.encrypt(mnemonics.entropy, with: key)
    }
    
    func decrypt(with key: Data) throws -> BIP39Mnemonics {
        let entropy = try AESCryptor.decrypt(data, with: key)
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
