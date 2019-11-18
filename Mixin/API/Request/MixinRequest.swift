import Foundation
import Alamofire
import Goutils
import DeviceGuru
import UIKit
import Bugsnag

class MixinRequest {

    fileprivate static let headersAuthroizationKey = "Authorization"
    private static let baseHeaders: HTTPHeaders = [
        "Content-Type": "application/json",
        "Accept-Language": Locale.current.languageCode ?? "en",
        "Mixin-Device-Id": Keychain.shared.getDeviceId(),
        "User-Agent": "Mixin/\(Bundle.main.shortVersion)(\(Bundle.main.bundleVersion)) (iOS \(UIDevice.current.systemVersion); \(DeviceGuru().hardware()); \(Locale.current.languageCode ?? "")-\(Locale.current.regionCode ?? ""))"
    ]

    private(set) var request: URLRequest!

    init(url: String, method: HTTPMethod, parameters: Parameters?, encoding: ParameterEncoding) throws {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = MixinRequest.baseHeaders
        self.request = try encoding.encode(request, with: parameters)
    }

    static func getHeaders(request: URLRequest) -> HTTPHeaders {
        var headers = MixinRequest.baseHeaders
        if let signedToken = MixinRequest.getAuthenticationToken(request: request) {
            headers[MixinRequest.headersAuthroizationKey] = signedToken
        }
        return headers
    }
    
    private static func signToken(sessionId: String, userId: String, authenticationToken: String, request: URLRequest) -> String? {
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
        
        let pem = KeyUtil.stripRsaPrivateKeyHeaders(authenticationToken)
        guard let key = KeyUtil.getPrivateKeyFromPem(pemString: pem) else {
            return nil
        }
        
        let claims = Jwt.Claims(uid: userId,
                                sid: sessionId,
                                iat: Date(),
                                exp: Date().addingTimeInterval(60 * 30),
                                jti: UUID().uuidString.lowercased(),
                                sig: sig.sha256(),
                                scp: "FULL")
        return try? Jwt.signedToken(claims: claims, privateKey: key)
    }

    fileprivate static func getAuthenticationToken(request: URLRequest) -> String? {
        guard let account = AccountAPI.shared.account, let token = AppGroupUserDefaults.Account.sessionSecret, !token.isEmpty else {
            return nil
        }
        guard let signedToken = signToken(sessionId: account.session_id, userId: account.user_id, authenticationToken: token, request: request) else {
            return nil
        }
        return "Bearer " + signedToken
    }
}

extension MixinRequest: URLRequestConvertible {

    func asURLRequest() throws -> URLRequest {
        return request
    }
}

class AccessTokenAdapter: RequestAdapter {

    func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        var urlRequest = urlRequest
        if let signedToken = MixinRequest.getAuthenticationToken(request: urlRequest) {
            urlRequest.setValue(signedToken, forHTTPHeaderField: MixinRequest.headersAuthroizationKey)
        }
        return urlRequest
    }

}
