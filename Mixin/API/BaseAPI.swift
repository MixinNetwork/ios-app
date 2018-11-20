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
    private static let jsonEncoding = JSONEncoding()
    
    private struct ResponseObject<ResultType: Codable>: Codable {
        let data: ResultType?
        let error: APIError?
    }
    private static let sharedSessionManager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        let session = Alamofire.SessionManager(configuration: configuration)
        session.adapter = AccessTokenAdapter()
        return session
    }()

    private func getRequest(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding) -> DataRequest {
        if url.hasSuffix("/") {
            assertionFailure("======BaseAPI get request url failed")
            UIApplication.trackError("BaseAPI", action: "get request url failed", userInfo: ["url": url])
        }
        
        do {
            return BaseAPI.sharedSessionManager.request(try MixinRequest(url: BaseAPI.rootURLString + url, method: method, parameters: parameters, encoding: encoding))
        } catch {
            Bugsnag.notifyError(error)
            return BaseAPI.sharedSessionManager.request(BaseAPI.rootURLString + url, method: method, parameters: parameters, encoding: encoding, headers: nil)
        }
    }

    @discardableResult
    func request<ResultType>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding, checkLogin: Bool = true, toastError: Bool = true, retry: Bool = false, completion: @escaping (APIResult<ResultType>) -> Void) -> Request? {
        if checkLogin && !AccountAPI.shared.didLogin {
            return nil
        }
        let request = getRequest(method: method, url: url, parameters: parameters, encoding: encoding)
        return request.validate(statusCode: 200...299)
            .responseData(completionHandler: { (response) in
                let httpStatusCode = response.response?.statusCode ?? -1
                let handerError = { (error: APIError) in
                    switch error.code {
                    case 401:
                        if let responseServerTime = response.response?.allHeaderFields["x-server-time"] as? String, let serverTime = Double(responseServerTime), serverTime > 0 {
                            let clientTime = Date().timeIntervalSince1970
                            if abs(serverTime / 1000000000 - clientTime) > 300 {
                                FileManager.default.writeLog(log: "BaseAPI...async request...clock skew...serverTime:\(serverTime)...clientTime:\(clientTime)")
                                AccountUserDefault.shared.hasClockSkew = true
                                DispatchQueue.main.async {
                                    WebSocketService.shared.disconnect()
                                    AppDelegate.current.window?.rootViewController = makeInitialViewController()
                                }
                                return
                            } else if !retry {
                                self.request(method: method, url: url, parameters: parameters, encoding: encoding, checkLogin: checkLogin, toastError: toastError, retry: true, completion: completion)
                                return
                            }
                        }
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
            return self.syncRequest(method: method, url: url, parameters: parameters, encoding: encoding)
        }
    }

    private func syncRequest<T: Codable>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding, retry: Bool = false) -> APIResult<T> {
        var result: APIResult<T> = .failure(APIError.createTimeoutError())
        var responseServerTime = ""
        let requestTime = Date()
        if AccountAPI.shared.didLogin {
            let semaphore = DispatchSemaphore(value: 0)
            getRequest(method: method, url: url, parameters: parameters, encoding: encoding)
                .validate(statusCode: 200...299)
                .responseData(completionHandler: { (response) in
                    let httpStatusCode = response.response?.statusCode ?? -1
                    responseServerTime = response.response?.allHeaderFields["x-server-time"] as? String ?? ""
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
                            result = .failure(APIError.createError(error: error, status: httpStatusCode))
                        }
                    case let .failure(error):
                        result = .failure(APIError.createError(error: error, status: httpStatusCode))
                    }
                    semaphore.signal()
                })

            if semaphore.wait(timeout: .now() + .seconds(8)) == .timedOut || Date().timeIntervalSince1970 - requestTime.timeIntervalSince1970 >= 8 {
                result = .failure(APIError(status: NSURLErrorTimedOut, code: -1, description: Localized.TOAST_API_ERROR_CONNECTION_TIMEOUT))
            }
        }

        if !result.isSuccess, case let .failure(error) = result, error.code == 401 {
            if let serverTime = Double(responseServerTime), serverTime > 0 {
                let clientTime = Date().timeIntervalSince1970
                FileManager.default.writeLog(log: "BaseAPI...sync request...clock skew...serverTime:\(serverTime)...clientTime:\(clientTime)...retry:\(retry)")
                if retry {
                    if abs(serverTime / 1000000000 - clientTime) > 300 {
                        AccountUserDefault.shared.hasClockSkew = true
                        DispatchQueue.main.async {
                            WebSocketService.shared.disconnect()
                            AppDelegate.current.window?.rootViewController = makeInitialViewController()
                        }
                        return result
                    }
                } else {
                    return syncRequest(method: method, url: url, parameters: parameters, encoding: encoding, retry: true)
                }
            }
            AccountAPI.shared.logout()
        }
        return result
    }
}
