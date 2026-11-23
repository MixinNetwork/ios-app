import Foundation

enum JWT {
    
    struct Claims: Encodable {
        let uid: String
        let sid: String
        let iat: Date
        let exp: Date
        let jti: String
        let sig: String
        let scp: String
    }
    
    enum Error: Swift.Error {
        case signAlgorithmNotSupported
        case building
        case sign(underlying: Swift.Error?)
    }
    
    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom({ (date, encoder) in
            let timeInterval = UInt64(date.timeIntervalSince1970)
            var container = encoder.singleValueContainer()
            try container.encode(timeInterval)
        })
        return encoder
    }()
    
    private static let edDSAHeader = #"{"alg":"EdDSA","typ":"JWT"}"#.data(using: .utf8)!.base64RawURLEncodedString()
    
    static func signedToken(claims: Claims, key: Ed25519PrivateKey) throws -> String {
        let base64EncodedClaims = try jsonEncoder.encode(claims).base64RawURLEncodedString()
        let headerAndPayload = edDSAHeader + "." + base64EncodedClaims
        guard let dataToSign = headerAndPayload.data(using: .utf8) else {
            throw Error.building
        }
        let signature = try key.signature(for: dataToSign)
        let base64EncodedSignature = signature.base64RawURLEncodedString()
        return headerAndPayload + "." + base64EncodedSignature
    }
    
}
