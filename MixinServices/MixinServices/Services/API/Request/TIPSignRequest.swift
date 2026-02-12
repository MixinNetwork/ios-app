import Foundation
import TIP

struct TIPSignRequest: Encodable {
    
    enum InitError: Error {
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
    init(id: String, userSk: TIPScalar, signer: TIPSigner, ephemeral: Data, watcher: Data, nonce: UInt64, grace: UInt64, assignee: Data?) throws {
        var error: NSError?
        let signerPk = TIPPoint(base58EncodedString: signer.identity)
        let userPk = try userSk.publicKey()
        guard let signerIdentity = signer.identity.data(using: .utf8) else {
            throw InitError.signerIdentity
        }
        guard let esum = SHA3_256.hash(data: ephemeral + signerIdentity) else {
            throw InitError.esum
        }
        
        var msg = userPk + esum + nonce.data(endianness: .big) + grace.data(endianness: .big)
        if let assignee = assignee {
            msg.append(assignee)
        }
        let sig = try userSk.sign(message: msg).hexEncodedString()
        
        let userPkString = TIPPoint.publicKeyString(publicKey: userPk)
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
        let cipher = TipEncrypt(
            signer.identity,
            userSk.bytes.hexEncodedString(),
            signJSON,
            &error
        )
        guard let cipher, error == nil else {
            throw InitError.cryptoEncrypt(error)
        }
        
        self.id = id
        self.signature = sig
        self.identity = userPkString
        self.data = cipher.base64RawURLEncodedString()
        self.watcher = watcherString
    }
    
}
