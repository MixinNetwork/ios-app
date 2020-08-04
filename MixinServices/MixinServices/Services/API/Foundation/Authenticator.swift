import Foundation
import DeviceGuru

enum Authenticator {
    
    private static let baseHeaders: [String: String] = [
        "Content-Type": "application/json",
        "Accept-Language": Locale.current.languageCode ?? "en",
        "Mixin-Device-Id": Keychain.shared.getDeviceId(),
        "User-Agent": "Mixin/\(Bundle.main.shortVersion) (iOS \(UIDevice.current.systemVersion); \(DeviceGuru().hardware()); \(Locale.current.languageCode ?? "")-\(Locale.current.regionCode ?? ""))"
    ]
    
    static func signedHeaders(for request: URLRequest) -> [String: String] {
        var headers = Self.baseHeaders
        if let signedToken = Self.signedToken(request: request) {
            headers["Authorization"] = signedToken
        }
        return headers
    }
    
    private static func signedToken(request: URLRequest) -> String? {
        guard let account = LoginManager.shared.account else {
            return nil
        }
        guard let token = AppGroupUserDefaults.Account.sessionSecret, !token.isEmpty else {
            return nil
        }
        guard let sig = sig(from: request) else {
            return nil
        }
        
        let pem = KeyUtil.stripRsaPrivateKeyHeaders(token)
        guard let key = KeyUtil.getPrivateKeyFromPem(pemString: pem) else {
            return nil
        }
        
        let date = Date()
        let claims = Jwt.Claims(uid: account.user_id,
                                sid: account.session_id,
                                iat: date,
                                exp: date.addingTimeInterval(30 * secondsPerMinute),
                                jti: UUID().uuidString.lowercased(),
                                sig: sig.sha256(),
                                scp: "FULL")
        guard let signedToken = try? Jwt.signedToken(claims: claims, privateKey: key) else {
            return nil
        }
        return "Bearer " + signedToken
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
