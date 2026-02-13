import Foundation
import TIP

struct TIPPoint {
    
    enum VerificationError: Error {
        case failed(Error)
        case invalidSignature
    }
    
    private let key: String
    
    init(base58EncodedString: String) {
        self.key = base58EncodedString
    }
    
    func verify(message: Data, signature: Data) throws(VerificationError) {
        var error: NSError?
        let result = TipPointVerify(key, message, signature, &error)
        if let error {
            throw .failed(error)
        } else if !result {
            throw .invalidSignature
        }
    }
    
}

extension TIPPoint {
    
    static func publicKeyString(publicKey: Data) -> String {
        TipPointPublicKeyString(publicKey)
    }
    
}
