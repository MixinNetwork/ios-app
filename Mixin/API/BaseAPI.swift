import Foundation
import Alamofire
import KeychainAccess
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
    case failure(error: APIError, didHandled: Bool)
}

class BaseAPI {
    
    static let jsonDecoder = JSONDecoder()
    static let jsonEncoder = JSONEncoder()
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

        let token = KeyUtil.stripRsaPrivateKeyHeaders(authenticationToken)
        let keyType = JWTCryptoKeyExtractor.privateKeyWithPEMBase64()
        let dataHolder = JWTAlgorithmRSFamilyDataHolder().keyExtractorType(keyType?.type)?.algorithmName("RS512")?.secret(token)
        return JWTEncodingBuilder.encodePayload(claims).addHolder(dataHolder)?.result?.successResult?.encoded
    }

    private static let headersAuthroizationKey = "Authorization"
    private static let baseHeaders: HTTPHeaders = [
        "Content-Type": "application/json",
        "Accept-Language": Locale.current.languageCode ?? "en",
        "Mixin-Device-Id": Keychain.getDeviceId(),
        "User-Agent": "Mixin/\(Bundle.main.shortVersion)(\(Bundle.main.bundleVersion)) (iOS \(UIDevice.current.systemVersion); \(DeviceGuru().hardware()); \(Locale.current.languageCode ?? "")-\(Locale.current.regionCode ?? ""))"
    ]
    private static let rootURL = "https://api.mixin.one/"
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
            originalRequest = try URLRequest(url: BaseAPI.rootURL + url, method: method)
            var encodedURLRequest = try encoding.encode(originalRequest!, with: parameters)
            encodedURLRequest.allHTTPHeaderFields = BaseAPI.getJwtHeaders(request: encodedURLRequest, uri: url)
            return BaseAPI.sharedSessionManager.request(encodedURLRequest)
        } catch {
            Bugsnag.notifyError(error)
            return BaseAPI.sharedSessionManager.request(BaseAPI.rootURL + url, method: method, parameters: parameters, encoding: encoding, headers: nil)
        }
    }

    @discardableResult
    func request<ResultType>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding, checkLogin: Bool = true, completion: @escaping (APIResult<ResultType>) -> Void) -> Request {
        let request = getRequest(method: method, url: url, parameters: parameters, encoding: encoding)
        if checkLogin && !AccountAPI.shared.didLogin {
            completion(.failure(error: APIError(code: 401, status: 401, description: "Unauthorized, maybe invalid token."), didHandled: false))
            return request
        }
        return request.validate(statusCode: 200...299)
            .responseData(completionHandler: { (response) in
                let httpStatusCode = response.response?.statusCode ?? -1
                switch response.result {
                case .success(let data):
                    do {
                        let responseObject = try BaseAPI.jsonDecoder.decode(ResponseObject<ResultType>.self, from: data)
                        if let data = responseObject.data {
                            completion(.success(data))
                        } else if let error = responseObject.error {
                            completion(.failure(error: error, didHandled: BaseAPI.handle(error: error, url: url)))
                        } else {
                            if let result = try? BaseAPI.jsonDecoder.decode(ResultType.self, from: data) {
                                completion(.success(result))
                            } else {
                                let error = APIError.badResponse(status: httpStatusCode, description: Localized.TOAST_API_ERROR_SERVER_DATA_ERROR)
                                completion(.failure(error: error, didHandled: BaseAPI.handle(error: error, url: url)))
                            }
                        }
                    } catch let error {
                        let apiError = APIError.jsonDecodingFailed(status: httpStatusCode, description: error.localizedDescription)
                        completion(.failure(error: apiError, didHandled: BaseAPI.handle(error: apiError, url: url)))
                    }
                case .failure(let error):
                    let nsError = error as NSError
                    let apiError = APIError(code: nsError.code, status: httpStatusCode, description: nsError.description)
                    completion(.failure(error: apiError, didHandled: BaseAPI.handle(error: apiError, url: url)))
                }
            })
    }

    // Return true if the error is handled, false if not
    @discardableResult
    static func handle(error: APIError, url: String) -> Bool {
        if (url == AccountAPI.url.verifyPin || url.hasPrefix("addresses/")) && error.kind != .invalidAPITokenHeader {
            return false
        }
        switch error.kind {
        case .invalidAPITokenHeader:
            UIApplication.trackError("BaseAPI", action: "401", userInfo: ["url": url])
            AccountAPI.shared.logout()
        case .internalServerError:
            NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.TOAST_SERVER_ERROR)
        case .timedOut:
            NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.TOAST_API_ERROR_CONNECTION_TIMEOUT)
        case .forbidden:
            NotificationCenter.default.postOnMain(name: .ErrorMessageDidAppear, object: Localized.TOAST_API_ERROR_FORBIDDEN)
        case .tooManyRequests:
            UIApplication.currentActivity()?.alert(Localized.TOAST_API_ERROR_TOO_MANY_REQUESTS)
        default:
            return false
        }
        return true
    }
    
}

extension BaseAPI {

    private static let sharedSynchronousSessionManager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8
        return Alamofire.SessionManager(configuration: configuration)
    }()

    @discardableResult
    func request<T: Codable>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding) -> Result<T> {
        guard AccountAPI.shared.didLogin else {
            return .failure(JobError.clientError(code: 401))
        }

        var result: Result<T>?
        var errorCode: Int?

        dispatchQueue.sync {
            let semaphore = DispatchSemaphore(value: 0)
            var errorMsg = ""

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
                                errorCode = error.code
                                errorMsg = error.description
                            } else {
                                if let model = try? BaseAPI.jsonDecoder.decode(T.self, from: data) {
                                    result = .success(model)
                                } else {
                                    errorCode = httpStatusCode
                                }
                            }
                        } catch {
                            errorCode = error.errorCode
                            errorMsg = error.localizedDescription
                        }
                    case let .failure(error):
                        errorCode = httpStatusCode
                        errorMsg = error.localizedDescription
                    }
                    semaphore.signal()
                })

            if semaphore.wait(timeout: .now() + .seconds(8)) == .timedOut {
                result = .failure(JobError.timeoutError)
            }
            if errorCode == 401 {
                var userInfo = UIApplication.getTrackUserInfo()
                userInfo["request"] = req.debugDescription
                userInfo["errorMsg"] = errorMsg
                UIApplication.trackError("BaseAPI", action: "401", userInfo: userInfo)
                AccountAPI.shared.logout()
            }
        }

        if let result = result {
            return result
        } else if let errorCode = errorCode {
            return .failure(JobError.instance(code: errorCode))
        } else {
            return .failure(JobError.networkError)
        }
    }
}
