import Foundation
import TIP

struct TIPSignRequest: Encodable {
    
    enum InitError: Error {
        case signerPk(NSError?)
        case userPublicKey
        case signerIdentity
        case esum
        case userPkString(NSError)
        case cryptoEncrypt(NSError?)
    }
    
    enum CodingKeys: CodingKey {
        // `id` will not be encoded but send with headers
        case signature
        case identity
        case data
        case watcher
        case action
    }
    
    private struct SignData: Encodable {
        let identity: String
        let assignee: String?
        let ephemeral: String
        let watcher: String
        let nonce: UInt64
        let grace: UInt64
        let rotate: String?
    }
    
    let id: String
    let signature: String
    let identity: String
    let data: String
    let watcher: String
    let action = "SIGN"
    
    @MainActor
    init(id: String, userSk: TipScalar, signer: TIPSigner, ephemeral: Data, watcher: Data, nonce: UInt64, grace: UInt64, assignee: Data?) throws {
        var error: NSError?
        guard let signerPk = TipPubKeyFromBase58(signer.identity, &error), error == nil else {
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
        let userPkBytes = try userPk.publicKeyBytes()
        
        var msg = userPkBytes + esum + nonce.data(endianness: .big) + grace.data(endianness: .big)
        if let assignee = assignee {
            msg.append(assignee)
        }
        let sig = try userSk.sign(msg).hexEncodedString()
        
        let userPkString = userPk.publicKeyString(&error)
        if let error {
            throw InitError.userPkString(error)
        }
        let watcherString = watcher.hexEncodedString()
        let signData = SignData(identity: userPkString,
                                assignee: assignee?.hexEncodedString(),
                                ephemeral: esum.hexEncodedString(),
                                watcher: watcherString,
                                nonce: nonce,
                                grace: grace,
                                rotate: nil)
        let signJSON = try JSONEncoder.default.encode(signData)
        guard let cipher = TipEncrypt(signerPk, userSk, signJSON, &error), error == nil else {
            throw InitError.cryptoEncrypt(error)
        }
        
        self.id = id
        self.signature = sig
        self.identity = userPkString
        self.data = cipher.base64RawURLEncodedString()
        self.watcher = watcherString
    }
    
}
