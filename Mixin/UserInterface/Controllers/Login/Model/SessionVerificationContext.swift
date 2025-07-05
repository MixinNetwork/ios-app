import Foundation
import CryptoKit
import MixinServices

final class SessionVerificationContext {
    
    private enum InitError: Error {
        case generateRandomData
        case generateMessageData
    }
    
    let mnemonics: MixinMnemonics
    let masterKey: Ed25519PrivateKey
    let publicKey: Data
    let message: Data
    let signature: Data
    
    init(mnemonics: MixinMnemonics) throws {
        let masterKey = try MasterKey.key(from: mnemonics)
        
        var random = Data(withNumberOfSecuredRandomBytes: 32)
        var messageData: Data!
        repeat {
            guard let thisRandom = random else {
                throw InitError.generateRandomData
            }
            let message = {
                let createdAt = Date().toUTCString()
                let random = thisRandom.hexEncodedString()
                let publicKey = masterKey.publicKey.rawRepresentation.hexEncodedString()
                return #"{"created_at":"\#(createdAt)","random":"\#(random)","master_public_hex":"\#(publicKey)"}"#
            }()
            guard let data = message.data(using: .utf8) else {
                throw InitError.generateMessageData
            }
            let hash = SHA256.hash(data: data)
            var it = hash.makeIterator()
            if it.next() == 0x00, let secondByte = it.next(), secondByte <= 0x0f {
                messageData = data
            } else {
                random = Data(withNumberOfSecuredRandomBytes: 32)
            }
        } while messageData == nil
        
        let signature = try masterKey.signature(for: messageData)
        let publicKey = masterKey.publicKey.rawRepresentation
        
        self.mnemonics = mnemonics
        self.masterKey = masterKey
        self.publicKey = publicKey
        self.message = messageData
        self.signature = signature
    }
    
}
