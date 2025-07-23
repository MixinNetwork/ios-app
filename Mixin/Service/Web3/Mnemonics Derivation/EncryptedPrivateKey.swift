import Foundation
import CryptoKit

struct EncryptedPrivateKey {
    
    enum EncryptionError: Error {
        case invalidLayout
    }
    
    let data: Data
    
    // Only provide `nonce` when testing
    init(privateKey: Data, key: Data, nonce: AES.GCM.Nonce? = nil) throws {
        let key = SymmetricKey(data: key)
        let box = try AES.GCM.seal(privateKey, using: key, nonce: nonce)
        guard let data = box.combined else {
            throw EncryptionError.invalidLayout
        }
        self.data = data
    }
    
    func decrypt(with key: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        let key = SymmetricKey(data: key)
        return try AES.GCM.open(box, using: key)
    }
    
}

extension EncryptedPrivateKey: Codable {
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.data = try container.decode(Data.self)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
    
}
