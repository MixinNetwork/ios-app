import Foundation

enum Jwt {
    
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
    
    private static let rs512Header = #"{"alg":"RS512","typ":"JWT"}"#.data(using: .utf8)!.base64RawURLEncodedString()
    private static let edDSAHeader = #"{"alg":"EdDSA","typ":"JWT"}"#.data(using: .utf8)!.base64RawURLEncodedString()
    
    static func signedToken(claims: Claims, privateKey: SecKey) throws -> String {
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, .rsaSignatureMessagePKCS1v15SHA512) else {
            throw Error.signAlgorithmNotSupported
        }
        let base64EncodedClaims = try jsonEncoder.encode(claims).base64RawURLEncodedString()
        let headerAndPayload = rs512Header + "." + base64EncodedClaims
        guard let dataToSign = headerAndPayload.data(using: .utf8) else {
            throw Error.building
        }
        var error: Unmanaged<CFError>? = nil
        guard let signature = SecKeyCreateSignature(privateKey, .rsaSignatureMessagePKCS1v15SHA512, dataToSign as CFData, &error) else {
            let retained = error?.takeRetainedValue()
            throw Error.sign(underlying: retained)
        }
        let base64EncodedSignature = (signature as Data).base64RawURLEncodedString()
        return headerAndPayload + "." + base64EncodedSignature
    }
    
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
