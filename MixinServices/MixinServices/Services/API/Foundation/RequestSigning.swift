import Foundation
import CryptoKit

enum RequestSigning {
    
    static var edDSAPrivateKey: Ed25519PrivateKey? {
        if let cached = cachedEdDSAPrivateKey {
            return cachedEdDSAPrivateKey
        } else if let secret = AppGroupKeychain.sessionSecret, let key = try? Ed25519PrivateKey(rawRepresentation: secret) {
            cachedEdDSAPrivateKey = key
            return key
        } else {
            return nil
        }
    }
    
    static func signedHeaders(for request: URLRequest) -> [String: String] {
        var headers = Self.baseHeaders
        let requestId = UUID().uuidString.lowercased()
        if let signedToken = Self.signedToken(request: request, requestId: requestId) {
            headers["Authorization"] = signedToken
        }
        headers["X-Request-Id"] = requestId
        return headers
    }
    
    static func removeCachedKey() {
        cachedEdDSAPrivateKey = nil
    }
    
}

extension RequestSigning {
    
    private static let baseHeaders: [String: String] = [
        "Content-Type": "application/json",
        "Accept-Language": Locale.current.languageCode ?? "en",
        "Mixin-Device-Id": Device.current.id,
        "User-Agent": MixinAPI.userAgent
    ]
    
    private static var cachedEdDSAPrivateKey: Ed25519PrivateKey?
    
    private static func signedToken(request: URLRequest, requestId: String) -> String? {
        guard let account = LoginManager.shared.account else {
            return nil
        }
        guard let sig = sig(from: request) else {
            return nil
        }
        
        let date = Date()
        let claims = Jwt.Claims(uid: account.userID,
                                sid: account.sessionID,
                                iat: date,
                                exp: date.addingTimeInterval(30 * secondsPerMinute),
                                jti: requestId,
                                sig: sig,
                                scp: "FULL")
        
        let token: String
        if let secret = AppGroupUserDefaults.Account.sessionSecret, !secret.isEmpty {
            let pem = KeyUtil.stripRsaPrivateKeyHeaders(secret)
            guard let key = KeyUtil.getPrivateKeyFromPem(pemString: pem) else {
                return nil
            }
            guard let signedToken = try? Jwt.signedToken(claims: claims, privateKey: key) else {
                return nil
            }
            token = signedToken
        } else if let key = edDSAPrivateKey, let signedToken = try? Jwt.signedToken(claims: claims, key: key) {
            token = signedToken
        } else {
            return nil
        }
        
        return "Bearer " + token
    }
    
    private static func sig(from request: URLRequest) -> String? {
        guard
            let url = request.url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            var uri = components.string
        else {
            return nil
        }
        if let range = components.rangeOfHost {
            uri.removeSubrange(range)
        }
        if let range = components.rangeOfScheme {
            uri.removeSubrange(range)
        }
        if uri.hasPrefix("://") {
            let start = uri.startIndex
            let end = uri.index(uri.startIndex, offsetBy: 2)
            uri.removeSubrange(start...end)
        }
        
        var string = ""
        if let method = request.httpMethod {
            string += method
        }
        if !uri.hasPrefix("/") {
            string += "/"
        }
        string += uri
        if let body = request.httpBody, let content = String(data: body, encoding: .utf8), content.count > 0 {
            string += content
        }
        
        guard let data = string.data(using: .utf8) else {
            return nil
        }
        let hash = SHA256.hash(data: data).hexEncodedString()
        return hash
    }
    
}
