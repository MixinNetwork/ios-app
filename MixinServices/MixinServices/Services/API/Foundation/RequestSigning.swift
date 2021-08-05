import Foundation
import DeviceGuru

enum RequestSigning {
    
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
        "Mixin-Device-Id": Keychain.shared.getDeviceId(),
        "User-Agent": "Mixin/\(Bundle.main.shortVersion) (iOS \(UIDevice.current.systemVersion); \(DeviceGuru().hardware()); \(Locale.current.languageCode ?? "")-\(Locale.current.regionCode ?? ""))"
    ]
    
    private static var cachedEdDSAPrivateKey: Ed25519PrivateKey?
    private static var edDSAPrivateKey: Ed25519PrivateKey? {
        if let cached = cachedEdDSAPrivateKey {
            return cachedEdDSAPrivateKey
        } else if let secret = AppGroupKeychain.sessionSecret, let key = Ed25519PrivateKey(rfc8032Representation: secret) {
            cachedEdDSAPrivateKey = key
            return key
        } else {
            return nil
        }
    }
    
    private static func signedToken(request: URLRequest, requestId: String) -> String? {
        guard let account = LoginManager.shared.account else {
            return nil
        }
        guard let sig = sig(from: request) else {
            return nil
        }
        
        let date = Date()
        let claims = Jwt.Claims(uid: account.user_id,
                                sid: account.session_id,
                                iat: date,
                                exp: date.addingTimeInterval(30 * secondsPerMinute),
                                jti: requestId,
                                sig: sig.sha256(),
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
        guard let url = request.url else {
            return nil
        }
        
        var uri = url.path
        if let query = url.query {
            uri += "?" + query
        }
        if let fragment = url.fragment {
            uri += "#" + fragment
        }
        
        var sig = ""
        if let method = request.httpMethod {
            sig += method
        }
        if !uri.hasPrefix("/") {
            sig += "/"
        }
        sig += uri
        if let body = request.httpBody, let content = String(data: body, encoding: .utf8), content.count > 0 {
            sig += content
        }
        
        return sig
    }
    
}
