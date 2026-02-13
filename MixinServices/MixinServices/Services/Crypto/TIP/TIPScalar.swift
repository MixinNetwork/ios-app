import Foundation
import TIP

struct TIPScalar {
    
    enum ScalarError: Error {
        case initialize(NSError?)
        case sign(NSError?)
        case export(NSError?)
    }
    
    let bytes: Data
    
    init(seed: Data) throws(ScalarError) {
        var error: NSError?
        let sk = TipNewPrivateKeyFromBytes(seed, &error)
        guard let sk, error == nil else {
            throw .initialize(error)
        }
        self.bytes = sk
    }
    
    func publicKey() throws(ScalarError) -> Data {
        var error: NSError?
        let pub = TipPublicKeyFromBytes(bytes, &error)
        guard let pub, error == nil else {
            throw .export(error)
        }
        return pub
    }
    
    func sign(message: Data) throws(ScalarError) -> Data {
        var error: NSError?
        let sig = TipSignFromBytes(bytes, message, &error)
        guard let sig, error == nil else {
            throw .sign(error)
        }
        return sig
    }
    
}
