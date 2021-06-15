import Foundation
import Alamofire
import UIKit

open class MixinAPI {
    
    public typealias Result<Response: Decodable> = Swift.Result<Response, MixinAPIError>
    
    @discardableResult
    public static func request<Parameters: Encodable, Response>(
        method: HTTPMethod,
        path: String,
        parameters: Parameters,
        requiresLogin: Bool = true,
        queue: DispatchQueue = .main,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request? {
        guard let url = url(with: path) else {
            queue.async {
                completion(.failure(.invalidPath))
            }
            return nil
        }
        return request(makeRequest: { (session) -> DataRequest in
            session.request(url, method: method, parameters: parameters, encoder: JSONParameterEncoder.default)
        }, requiresLogin: requiresLogin, isAsync: true, completion: completion)
    }
    
    @discardableResult
    public static func request<Response>(
        method: HTTPMethod,
        path: String,
        parameters: [String: Any]? = nil,
        requiresLogin: Bool = true,
        queue: DispatchQueue = .main,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request? {
        guard let url = url(with: path) else {
            queue.async {
                completion(.failure(.invalidPath))
            }
            return nil
        }
        return request(makeRequest: { (session) -> DataRequest in
            session.request(url, method: method, parameters: parameters, encoding: JSONEncoding.default)
        }, requiresLogin: requiresLogin, isAsync: true, completion: completion)
    }
    
    @discardableResult
    public static func request<Parameters: Encodable, Response>(
        method: HTTPMethod,
        path: String,
        parameters: Parameters
    ) -> MixinAPI.Result<Response> {
        guard let url = url(with: path) else {
            return .failure(.invalidPath)
        }
        return request(makeRequest: { (session) -> DataRequest in
            session.request(url, method: method, parameters: parameters, encoder: JSONParameterEncoder.default) { (request) in
                request.timeoutInterval = requestTimeout
            }
        }, debugDescription: path)
    }
    
    @discardableResult
    public static func request<Response>(
        method: HTTPMethod,
        path: String,
        parameters: [String: Any]? = nil
    ) -> MixinAPI.Result<Response> {
        guard let url = url(with: path) else {
            return .failure(.invalidPath)
        }
        return request(makeRequest: { (session) -> DataRequest in
            session.request(url, method: method, parameters: parameters, encoding: JSONEncoding.default) { (request) in
                request.timeoutInterval = requestTimeout
            }
        }, debugDescription: path)
    }
    
}

extension MixinAPI {
    
    private struct ResponseObject<Response: Decodable>: Decodable {
        let data: Response?
        let error: MixinAPIError?
    }
    
    private static let session: Alamofire.Session = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let tokenInterceptor = AccessTokenInterceptor()
        let session = Alamofire.Session(configuration: config, interceptor: tokenInterceptor)
        return session
    }()
    
    private static func url(with path: String) -> URL? {
        let string = "https://" + MixinHost.http + path
        return URL(string: string)
    }
    
    private static func request<Response>(
        makeRequest: @escaping (Alamofire.Session) -> DataRequest,
        debugDescription: String
    ) -> MixinAPI.Result<Response> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: MixinAPI.Result<Response> = .failure(.foundNilResult)
        
        let request = Self.request(makeRequest: makeRequest, isAsync: false) { (theResult: MixinAPI.Result<Response>) in
            result = theResult
            semaphore.signal()
        }
        if request != nil {
            semaphore.wait()
        }
        
        if case let .failure(error) = result, error.isTransportTimedOut {
            Logger.write(log: "[MixinAPI][SyncRequest]...timeout...requestTimeout:\(requestTimeout)... \(debugDescription)")
        }
        
        return result
    }
    
    @discardableResult
    private static func request<Response>(
        makeRequest: @escaping (Alamofire.Session) -> DataRequest,
        requiresLogin: Bool = true,
        isAsync: Bool,
        queue: DispatchQueue = .main,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request? {
        if requiresLogin && !LoginManager.shared.isLoggedIn {
            return nil
        }
        let requestTime = Date()
        let host = MixinHost.http
        
        func handleDeauthorization(response: HTTPURLResponse?) {
            let xServerTime = TimeInterval(response?.allHeaderFields[caseInsensitive: "x-server-time"] ?? "0") ?? 0
            let serverTimeIntervalSince1970 = xServerTime / TimeInterval(NSEC_PER_SEC)
            let serverTime = Date(timeIntervalSince1970: serverTimeIntervalSince1970)
            if abs(requestTime.timeIntervalSinceNow) > secondsPerMinute {
                request(makeRequest: makeRequest, requiresLogin: requiresLogin, isAsync: isAsync, completion: completion)
            } else if abs(serverTime.timeIntervalSinceNow) > 5 * secondsPerMinute {
                AppGroupUserDefaults.Account.isClockSkewed = true
                DispatchQueue.main.async {
                    WebSocketService.shared.disconnect()
                    NotificationCenter.default.post(name: MixinService.clockSkewDetectedNotification, object: self)
                }
                completion(.failure(.clockSkewDetected))
            } else {
                completion(.failure(.unauthorized))
                reporter.report(error: MixinServicesError.logout(isAsyncRequest: true))
                let reason = isAsync ? "AsyncRequest" : "SyncRequest"
                LoginManager.shared.logout(from: reason)
            }
        }
        
        return makeRequest(session)
            .validate(statusCode: 200...299)
            .responseData(queue: queue, completionHandler: { (response) in
                switch response.result {
                case .success(let data):
                    if let requestId = response.request?.allHTTPHeaderFields?["X-Request-Id"], !requestId.isEmpty {
                        let responseRequestId = response.response?.allHeaderFields[caseInsensitive: "x-request-id"] ?? ""
                        if requestId != responseRequestId {
                            Logger.write(errorMsg: "[MixinAPI][\(response.request?.url?.path ?? "")][X-Request-Id][\(requestId)]...response...\(response.response?.allHeaderFields)")
                            completion(.failure(.internalServerError))
                            return
                        }
                    }
                    do {
                        let responseObject = try JSONDecoder.default.decode(ResponseObject<Response>.self, from: data)
                        if let data = responseObject.data {
                            completion(.success(data))
                        } else if case .unauthorized = responseObject.error {
                            handleDeauthorization(response: response.response)
                        } else if let error = responseObject.error {
                            completion(.failure(error))
                        } else {
                            completion(.success(try JSONDecoder.default.decode(Response.self, from: data)))
                        }
                    } catch {
                        Logger.write(error: error, extra: "data decode failed.")
                        reporter.report(error: error)
                        completion(.failure(.invalidJSON(error)))
                    }
                case let .failure(error):
                    let requestId = response.request?.allHTTPHeaderFields?["X-Request-Id"] ?? ""
                    Logger.write(error: error, extra: "[\(response.request?.url?.path ?? "")][X-Request-Id]\(requestId)...")
                    if shouldToggleServer(for: error) {
                        MixinHost.toggle(currentHttpHost: host)
                    }
                    completion(.failure(.httpTransport(error)))
                }
            })
    }
    
    private static func shouldToggleServer(for error: AFError) -> Bool {
        guard ReachabilityManger.shared.isReachable else {
            return false
        }
        if case .responseValidationFailed(.unacceptableStatusCode) = error {
            return true
        } else if let underlying = error.underlyingError {
            let nsError = underlying as NSError
            let codes = [
                NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorCannotFindHost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorResourceUnavailable
            ]
            return nsError.domain == NSURLErrorDomain
                && codes.contains(nsError.code)
        } else {
            return false
        }
    }
    
}

fileprivate extension Dictionary where Key == AnyHashable, Value == Any {
    
    subscript(caseInsensitive key: String) -> String? {
        get {
            if let k = keys.first(where: { ($0 as? String)?.lowercased() == key }) {
                return self[k] as? String
            }
            return nil
        }
        set {
            if let k = keys.first(where: { ($0 as? String)?.lowercased() == key }) {
                self[k] = newValue
            } else {
                self[key] = newValue
            }
        }
    }
    
}
