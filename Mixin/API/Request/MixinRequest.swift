import Foundation
import Alamofire
import Goutils
import DeviceGuru
import UIKit
import Bugsnag
import JWT

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
        } else {
            UIApplication.trackError("MixinRequest", action: "getSignedRequest Will 401", userInfo: UIApplication.getTrackUserInfo())
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
        var claims: [AnyHashable: Any] = [:]
        claims["uid"] = userId
        claims["sid"] = sessionId
        claims["iat"] = UInt64(Date().timeIntervalSince1970)
        claims["exp"] = UInt64(Date().addingTimeInterval(60 * 30).timeIntervalSince1970)
        claims["jti"] = UUID().uuidString.lowercased()
        claims["sig"] = sig.sha256()
        claims["scp"] = "FULL"

        let token = KeyUtil.stripRsaPrivateKeyHeaders(authenticationToken)
        let keyType = JWTCryptoKeyExtractor.privateKeyWithPEMBase64()
        var holder: JWTAlgorithmRSFamilyDataHolder? = JWTAlgorithmRSFamilyDataHolder()
        holder = holder?.keyExtractorType(keyType?.type)
        holder = holder?.algorithmName("RS512") as? JWTAlgorithmRSFamilyDataHolder
        holder = holder?.secret(token) as? JWTAlgorithmRSFamilyDataHolder
        var builder = JWTEncodingBuilder.encodePayload(claims)
        builder = builder?.addHolder(holder) as? JWTEncodingBuilder
        let result = builder?.result?.successResult?.encoded
        return result
    }

    fileprivate static func getAuthenticationToken(request: URLRequest) -> String? {
        guard let account = AccountAPI.shared.account, let token = AccountUserDefault.shared.getToken(), !token.isEmpty else {
            return nil
        }
        guard let signedToken = signToken(sessionId: account.session_id, userId: account.user_id, authenticationToken: token, request: request) else {
            UIApplication.trackError("MixinRequest", action: "Will 401", userInfo: ["authenticationToken": token, "session_id": account.session_id, "user_id": account.user_id, "didLogin": "\(AccountAPI.shared.didLogin)"])
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
