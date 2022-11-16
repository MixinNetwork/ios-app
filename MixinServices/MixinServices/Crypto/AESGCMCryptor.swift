import Foundation
import CryptoKit

// This cryptor appends tag of tagLength to the cipher on encryption, and
// expect a tag on trailing of cipher on decryption. Feel free to change
// this behavior if needed
enum AESGCMCryptor {
    
    enum Error: Swift.Error {
        case invalidKey(Int)
        case invalidCipher(Int)
    }
    
    static let tagCount = 16
    static let keyCount = 16
    
    static func encrypt(_ plain: Data, with key: Data, iv: Data) throws -> Data {
        guard key.count >= keyCount else {
            throw Error.invalidKey(key.count)
        }
        let nonce = try AES.GCM.Nonce(data: iv)
        let trimmedKey = CryptoKit.SymmetricKey(data: key.prefix(keyCount))
        let encrypted = try AES.GCM.seal(plain, using: trimmedKey, nonce: nonce)
        return encrypted.ciphertext + encrypted.tag
    }
    
    static func decrypt(_ cipher: Data, with key: Data, iv: Data) throws -> Data {
        guard cipher.count > tagCount else {
            throw Error.invalidCipher(cipher.count)
        }
        let nonce = try AES.GCM.Nonce(data: iv)
        let ciphertext = cipher.dropLast(tagCount)
        let tag = cipher.suffix(tagCount)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let trimmedKey = CryptoKit.SymmetricKey(data: key.prefix(keyCount))
        return try AES.GCM.open(box, using: trimmedKey)
    }
    
}
