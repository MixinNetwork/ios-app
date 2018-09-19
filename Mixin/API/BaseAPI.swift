import Foundation
import Alamofire
import Goutils
import DeviceGuru
import UIKit
import Bugsnag
import JWT

fileprivate let jsonContentKey = "jsonArray"

extension Array {

    func toParameters() -> Parameters {
        return [jsonContentKey: self]
    }

}

extension Encodable {

    func toParameters() -> Parameters {
        return [jsonContentKey: self]
    }

}

struct EncodableParameterEncoding<T: Encodable>: ParameterEncoding {

    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let parameters = parameters, let encodable = parameters[jsonContentKey] as? T else {
            return urlRequest
        }
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            let data = try JSONEncoder().encode(encodable)
            urlRequest.httpBody = data
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        return urlRequest
    }
}

struct JSONArrayEncoding: ParameterEncoding {

    let options: JSONSerialization.WritingOptions

    init(options: JSONSerialization.WritingOptions = []) {
        self.options = options
    }

    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let parameters = parameters, let array = parameters[jsonContentKey] else { return urlRequest }
        do {
            let data = try JSONSerialization.data(withJSONObject: array, options: options)
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            urlRequest.httpBody = data
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
        return urlRequest
    }

}

enum APIResult<ResultType: Codable> {
    case success(ResultType)
    case failure(APIError)

    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

class BaseAPI {
    
    static let jsonDecoder = JSONDecoder()
    static let jsonEncoder = JSONEncoder()
    static let rootURLString = "https://api.mixin.one/"
    static let rootURL = URL(string: rootURLString)!
    
    private let dispatchQueue = DispatchQueue(label: "one.mixin.messenger.queue.api")

    static func getJwtHeaders(request: URLRequest, uri: String) -> HTTPHeaders {
        var headers = baseHeaders
        if let account = AccountAPI.shared.account, let token = AccountUserDefault.shared.getToken(), !token.isEmpty {
            if let signedToken = signToken(sessionId: account.session_id, userId: account.user_id, authenticationToken: token, request: request, uri: uri) {
                headers[headersAuthroizationKey] = "Bearer " + signedToken
            } else {
                UIApplication.trackError("BaseAPI", action: "Will 401", userInfo: ["authenticationToken": token, "session_id": account.session_id, "user_id": account.user_id, "didLogin": "\(AccountAPI.shared.didLogin)"])
            }
        }
        return headers
    }

    private static func signToken(sessionId: String, userId: String, authenticationToken: String, request: URLRequest, uri: String) -> String? {
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
        return JWTEncodingBuilder.encodePayload(claims).addHolder(holder)?.result?.successResult?.encoded
    }

    private static let headersAuthroizationKey = "Authorization"
    private static let baseHeaders: HTTPHeaders = [
        "Content-Type": "application/json",
        "Accept-Language": Locale.current.languageCode ?? "en",
        "Mixin-Device-Id": Keychain.shared.getDeviceId(),
        "User-Agent": "Mixin/\(Bundle.main.shortVersion)(\(Bundle.main.bundleVersion)) (iOS \(UIDevice.current.systemVersion); \(DeviceGuru().hardware()); \(Locale.current.languageCode ?? "")-\(Locale.current.regionCode ?? ""))"
    ]
    private static let jsonEncoding = JSONEncoding()
    
    private struct ResponseObject<ResultType: Codable>: Codable {
        let data: ResultType?
        let error: APIError?
    }
    private static let sharedSessionManager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        return Alamofire.SessionManager(configuration: configuration)
    }()

    private func getRequest(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding) -> DataRequest {
        if url.hasSuffix("/") {
            assertionFailure("======BaseAPI get request url failed")
            UIApplication.trackError("BaseAPI", action: "get request url failed", userInfo: ["url": url])
        }
        var originalRequest: URLRequest?
        do {
            originalRequest = try URLRequest(url: BaseAPI.rootURLString + url, method: method)
            var encodedURLRequest = try encoding.encode(originalRequest!, with: parameters)
            encodedURLRequest.allHTTPHeaderFields = BaseAPI.getJwtHeaders(request: encodedURLRequest, uri: url)
            return BaseAPI.sharedSessionManager.request(encodedURLRequest)
        } catch {
            Bugsnag.notifyError(error)
            return BaseAPI.sharedSessionManager.request(BaseAPI.rootURLString + url, method: method, parameters: parameters, encoding: encoding, headers: nil)
        }
    }

    @discardableResult
    func request<ResultType>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding, checkLogin: Bool = true, toastError: Bool = true, completion: @escaping (APIResult<ResultType>) -> Void) -> Request? {
        if checkLogin && !AccountAPI.shared.didLogin {
            return nil
        }
        let requestTime = DateFormatter.filename.string(from: Date())
        let request = getRequest(method: method, url: url, parameters: parameters, encoding: encoding)
        return request.validate(statusCode: 200...299)
            .responseData(completionHandler: { (response) in
                let httpStatusCode = response.response?.statusCode ?? -1
                let handerError = { (error: APIError) in
                    switch error.code {
                    case 401:
                        var userInfo = UIApplication.getTrackUserInfo()
                        userInfo["request"] = request.debugDescription
                        userInfo["startRequestTime"] = requestTime
                        UIApplication.trackError("BaseAPI async request", action: "401", userInfo: userInfo)
                        AccountAPI.shared.logout()
                        return
                    case 429:
                        if url != AccountAPI.url.verifyPin && !url.contains(AccountAPI.url.verifications) {
                            UIApplication.currentActivity()?.alert(Localized.TOAST_API_ERROR_TOO_MANY_REQUESTS)
                            return
                        }
                    default:
                        if toastError {
                            NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: error.localizedDescription)
                        }
                    }
                    completion(.failure(error))
                }
                switch response.result {
                case .success(let data):
                    do {
                        let responseObject = try BaseAPI.jsonDecoder.decode(ResponseObject<ResultType>.self, from: data)
                        if let data = responseObject.data {
                            completion(.success(data))
                        } else if let error = responseObject.error {
                            handerError(error)
                        } else {
                            completion(.success(try BaseAPI.jsonDecoder.decode(ResultType.self, from: data)))
                        }
                    } catch {
                        handerError(APIError.createError(error: error, status: httpStatusCode))
                    }
                case let .failure(error):
                    handerError(APIError.createError(error: error, status: httpStatusCode))
                }
            })
    }

}

extension BaseAPI {

    private static let sharedSynchronousSessionManager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8
        return Alamofire.SessionManager(configuration: configuration)
    }()

    @discardableResult
    func request<T: Codable>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding) -> APIResult<T> {
        return dispatchQueue.sync {
            var result: APIResult<T> = .failure(APIError.createTimeoutError())
            var debugDescription = ""
            let requestTime = Date()
            var errorMsg = ""
            if AccountAPI.shared.didLogin {
                let semaphore = DispatchSemaphore(value: 0)
                let req = getRequest(method: method, url: url, parameters: parameters, encoding: encoding)
                    .validate(statusCode: 200...299)
                    .responseData(completionHandler: { (response) in
                        let httpStatusCode = response.response?.statusCode ?? -1
                        switch response.result {
                        case let .success(data):
                            do {
                                let responseObject = try BaseAPI.jsonDecoder.decode(ResponseObject<T>.self, from: data)
                                if let data = responseObject.data {
                                    result = .success(data)
                                } else if let error = responseObject.error {
                                    result = .failure(error)
                                } else {
                                    let model = try BaseAPI.jsonDecoder.decode(T.self, from: data)
                                    result = .success(model)
                                }
                            } catch {
                                errorMsg = "decode error:\(error)"
                                result = .failure(APIError.createError(error: error, status: httpStatusCode))
                            }
                        case let .failure(error):
                            errorMsg = "api error:\(error)"
                            result = .failure(APIError.createError(error: error, status: httpStatusCode))
                        }
                        semaphore.signal()
                    })

                if semaphore.wait(timeout: .now() + .seconds(8)) == .timedOut || Date().timeIntervalSince1970 - requestTime.timeIntervalSince1970 >= 8 {
                    result = .failure(APIError(status: NSURLErrorTimedOut, code: -1, description: Localized.TOAST_API_ERROR_CONNECTION_TIMEOUT))
                }
                debugDescription = req.debugDescription
            }

            if !result.isSuccess, case let .failure(error) = result, error.code == 401 {
                if AccountAPI.shared.didLogin {
                    var userInfo = UIApplication.getTrackUserInfo()
                    userInfo["request"] = debugDescription
                    userInfo["startRequestTime"] = DateFormatter.filename.string(from: requestTime)
                    userInfo["errorMsg"] = errorMsg
                    UIApplication.trackError("BaseAPI sync request", action: "401", userInfo: userInfo)
                }
                AccountAPI.shared.logout()
            }
            return result
        }
    }
}
