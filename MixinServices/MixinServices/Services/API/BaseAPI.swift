import Foundation
import Alamofire
import Goutils
import DeviceGuru
import UIKit

public enum APIResult<ResultType: Codable> {
    case success(ResultType)
    case failure(APIError)

    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}

open class BaseAPI {
    
    public static let jsonEncoding = JSONEncoding()
    
    private let dispatchQueue = DispatchQueue(label: "one.mixin.services.queue.api")
    
    public init() {
        
    }
    
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
        do {
            return BaseAPI.sharedSessionManager.request(try MixinRequest(url: MixinServer.httpUrl + url, method: method, parameters: parameters, encoding: encoding))
        } catch {
            Reporter.report(error: error)
            return BaseAPI.sharedSessionManager.request(MixinServer.httpUrl + url, method: method, parameters: parameters, encoding: encoding, headers: nil)
        }
    }

    @discardableResult
    public func request<ResultType>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding, checkLogin: Bool = true, retry: Bool = false, completion: @escaping (APIResult<ResultType>) -> Void) -> Request? {
        if checkLogin && !LoginManager.shared.isLoggedIn {
            return nil
        }
        let request = getRequest(method: method, url: url, parameters: parameters, encoding: encoding)
        let requestTime = Date()
        let rootURLString = MixinServer.httpUrl
        return request.validate(statusCode: 200...299)
            .responseData(completionHandler: { (response) in
                let httpStatusCode = response.response?.statusCode ?? -1
                let handerError = { (error: APIError) in
                    switch error.code {
                    case 401:
                        if let responseServerTime = response.response?.allHeaderFields["x-server-time"] as? String, let serverTime = Double(responseServerTime), serverTime > 0 {
                            let clientTime = Date().timeIntervalSince1970
                            if clientTime - requestTime.timeIntervalSince1970 > 60 {
                                self.request(method: method, url: url, parameters: parameters, encoding: encoding, checkLogin: checkLogin, retry: true, completion: completion)
                                return
                            } else {
                                if abs(serverTime / 1000000000 - clientTime) > 300 {
                                    AppGroupUserDefaults.Account.isClockSkewed = true
                                    DispatchQueue.main.async {
                                        WebSocketService.shared.disconnect()
                                        NotificationCenter.default.post(name: MixinService.clockSkewDetectedNotification, object: self)
                                    }
                                    return
                                }
                            }
                        }
                        Reporter.report(error: MixinServicesError.logout(isAsyncRequest: true))
                        LoginManager.shared.logout(from: "AsyncRequest")
                        return
                    default:
                        break
                    }
                    completion(.failure(error))
                }
                switch response.result {
                case .success(let data):
                    do {
                        let responseObject = try JSONDecoder.default.decode(ResponseObject<ResultType>.self, from: data)
                        if let data = responseObject.data {
                            completion(.success(data))
                        } else if let error = responseObject.error {
                            handerError(error)
                        } else {
                            completion(.success(try JSONDecoder.default.decode(ResultType.self, from: data)))
                        }
                    } catch {
                        handerError(APIError.createError(error: error, status: httpStatusCode))
                    }
                case let .failure(error):
                    if NetworkManager.shared.isReachable {
                        switch error._code {
                        case NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed, NSURLErrorResourceUnavailable:
                            MixinServer.toggle(currentHttpUrl: rootURLString)
                        default:
                            break
                        }
                    }
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
    public func request<T: Codable>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding) -> APIResult<T> {
        return dispatchQueue.sync {
            return self.syncRequest(method: method, url: url, parameters: parameters, encoding: encoding)
        }
    }

    private func syncRequest<T: Codable>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = BaseAPI.jsonEncoding, retry: Bool = false) -> APIResult<T> {
        var result: APIResult<T> = .failure(APIError.createTimeoutError())
        var responseServerTime = ""
        let requestTime = Date()
        let rootURLString = MixinServer.httpUrl
        if LoginManager.shared.isLoggedIn {
            let semaphore = DispatchSemaphore(value: 0)
            getRequest(method: method, url: url, parameters: parameters, encoding: encoding)
                .validate(statusCode: 200...299)
                .responseData(completionHandler: { (response) in
                    let httpStatusCode = response.response?.statusCode ?? -1
                    responseServerTime = response.response?.allHeaderFields["x-server-time"] as? String ?? ""
                    switch response.result {
                    case let .success(data):
                        do {
                            let responseObject = try JSONDecoder.default.decode(ResponseObject<T>.self, from: data)
                            if let data = responseObject.data {
                                result = .success(data)
                            } else if let error = responseObject.error {
                                result = .failure(error)
                            } else {
                                let model = try JSONDecoder.default.decode(T.self, from: data)
                                result = .success(model)
                            }
                        } catch {
                            result = .failure(APIError.createError(error: error, status: httpStatusCode))
                        }
                    case let .failure(error):
                        if NetworkManager.shared.isReachable {
                            switch error._code {
                            case NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed, NSURLErrorResourceUnavailable:
                                MixinServer.toggle(currentHttpUrl: rootURLString)
                            default:
                                break
                            }
                        }
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
                if clientTime - requestTime.timeIntervalSince1970 > 60 {
                    return syncRequest(method: method, url: url, parameters: parameters, encoding: encoding, retry: true)
                } else {
                    if abs(serverTime / 1000000000 - clientTime) > 300 {
                        AppGroupUserDefaults.Account.isClockSkewed = true
                        DispatchQueue.main.async {
                            WebSocketService.shared.disconnect()
                            NotificationCenter.default.post(name: MixinService.clockSkewDetectedNotification, object: self)
                        }
                        return result
                    }
                }
            }
            Reporter.report(error: MixinServicesError.logout(isAsyncRequest: false))
            LoginManager.shared.logout(from: "SyncRequest")
        }
        return result
    }
}
