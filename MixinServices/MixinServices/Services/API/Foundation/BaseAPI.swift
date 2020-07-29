import Foundation
import Alamofire
import Goutils
import UIKit

open class BaseAPI {
    
    public typealias Result<Response: Decodable> = Swift.Result<Response, APIError>
    
    public init() {

    }
    
    private struct ResponseObject<ResultType: Decodable>: Decodable {
        let data: ResultType?
        let error: APIError?
    }
    private static let session: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        let tokenInterceptor = AccessTokenInterceptor()
        let session = Alamofire.Session(configuration: configuration,
                                        interceptor: tokenInterceptor)
        return session
    }()

    private func getRequest(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = JSONEncoding.default) -> DataRequest {
        do {
            return BaseAPI.session.request(try MixinRequest(url: MixinServer.httpUrl + url, method: method, parameters: parameters, encoding: encoding))
        } catch {
            reporter.report(error: error)
            return BaseAPI.session.request(MixinServer.httpUrl + url, method: method, parameters: parameters, encoding: encoding, headers: nil)
        }
    }

    @discardableResult
    public func request<ResultType>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = JSONEncoding.default, checkLogin: Bool = true, retry: Bool = false, completion: @escaping (BaseAPI.Result<ResultType>) -> Void) -> Request? {
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
                        reporter.report(error: MixinServicesError.logout(isAsyncRequest: true))
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
    
    @discardableResult
    public func request<T: Codable>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = JSONEncoding.default) -> BaseAPI.Result<T> {
        return syncRequest(method: method, url: url, parameters: parameters, encoding: encoding)
    }

    private func syncRequest<T: Codable>(method: HTTPMethod, url: String, parameters: Parameters? = nil, encoding: ParameterEncoding = JSONEncoding.default, retry: Bool = false) -> BaseAPI.Result<T> {
        var result: BaseAPI.Result<T> = .failure(APIError.createTimeoutError())
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

            if semaphore.wait(timeout: .now() + .seconds(requestTimeout)) == .timedOut || Date().timeIntervalSince1970 - requestTime.timeIntervalSince1970 >= Double(requestTimeout) {
                reporter.reportErrorToFirebase(MixinServicesError.requestTimeout("http"))
                Logger.write(log: "[BaseAPI][SyncRequest]...timeout...requestTimeout:\(requestTimeout)... \(url)")
                result = .failure(APIError(status: NSURLErrorTimedOut, code: -1, description: Localized.TOAST_API_ERROR_CONNECTION_TIMEOUT))
            }
        }

        if case let .failure(error) = result, error.code == 401 {
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
            reporter.report(error: MixinServicesError.logout(isAsyncRequest: false))
            LoginManager.shared.logout(from: "SyncRequest")
        }
        return result
    }
}
