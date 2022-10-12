import Foundation
import Tip

struct TIPSignRequest: Encodable {
    
    enum InitError: Error {
        case signerPk(NSError?)
        case userPublicKey
        case signerIdentity
        case esum
        case userPkBytes
        case cryptoEncrypt
    }
    
    struct SignData: Encodable {
        let identity: String
        let assignee: String?
        let ephemeral: String
        let watcher: String
        let nonce: UInt64
        let grace: UInt64
        let rotate: String?
    }
    
    let signature: String
    let identity: String
    let data: String
    let watcher: String
    let action = "SIGN"
    
    init(userSk: CryptoScalar, signer: TIPSigner, ephemeral: Data, watcher: Data, nonce: UInt64, grace: UInt64, assignee: Data?) throws {
        var error: NSError?
        guard let signerPk = CryptoPubKeyFromBase58(signer.identity, &error) else {
            throw InitError.signerPk(error)
        }
        guard let userPk = userSk.publicKey() else {
            throw InitError.userPublicKey
        }
        guard let signerIdentity = signer.identity.data(using: .utf8) else {
            throw InitError.signerIdentity
        }
        guard let esum = SHA3_256.hash(data: ephemeral + signerIdentity) else {
            throw InitError.esum
        }
        guard let userPkBytes = userPk.publicKeyBytes() else {
            throw InitError.userPkBytes
        }
        
        var msg = userPkBytes + esum + nonce.data(endianness: .big) + grace.data(endianness: .big)
        if let assignee = assignee {
            msg.append(assignee)
        }
        let sig = try userSk.sign(msg).hexEncodedString()
        
        let userPkString = userPk.publicKeyString()
        let watcherString = watcher.hexEncodedString()
        let signData = SignData(identity: userPkString,
                                assignee: assignee?.hexEncodedString(),
                                ephemeral: esum.hexEncodedString(),
                                watcher: watcherString,
                                nonce: nonce,
                                grace: grace,
                                rotate: nil)
        let signJSON = try JSONEncoder.default.encode(signData)
        guard let cipher = CryptoEncrypt(signerPk, userSk, signJSON) else {
            throw InitError.cryptoEncrypt
        }
        
        self.signature = sig
        self.identity = userPkString
        self.data = cipher.base64RawURLEncodedString()
        self.watcher = watcherString
    }
    
}