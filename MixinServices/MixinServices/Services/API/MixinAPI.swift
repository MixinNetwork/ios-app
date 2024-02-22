import Foundation
import Alamofire
import UIKit

open class MixinAPI {
    
    public typealias Result<Response: Decodable> = Swift.Result<Response, MixinAPIError>
    
    public struct Options: OptionSet {
        
        public static let authIndependent = Options(rawValue: 1 << 0)
        public static let disableRetryOnRequestSigningTimeout = Options(rawValue: 1 << 1)
        
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
    }
    
    // Async version, model as parameter
    public static func request<Parameters: Encodable, Response: Decodable>(
        method: HTTPMethod,
        path: String,
        parameters: Parameters,
        options: Options = [],
        queue: DispatchQueue = .main
    ) async throws -> Response {
        guard let url = url(with: path) else {
            throw MixinAPIError.invalidPath
        }
        return try await withCheckedThrowingContinuation { continuation in
            request(makeRequest: { (session) -> DataRequest in
                session.request(url, method: method, parameters: parameters, encoder: JSONParameterEncoder.default)
            }, options: options, isAsync: true, queue: queue, completion: { result in
                continuation.resume(with: result)
            })
        }
    }
    
    // Callback version, model as parameter
    @discardableResult
    public static func request<Parameters: Encodable, Response>(
        method: HTTPMethod,
        path: String,
        parameters: Parameters,
        options: Options = [],
        queue: DispatchQueue = .main,
        completion: @escaping (Result<Response>) -> Void
    ) -> Request? {
        guard let url = url(with: path) else {
            queue.async {
                completion(.failure(.invalidPath))
            }
            return nil
        }
        return request(makeRequest: { (session) -> DataRequest in
            session.request(url, method: method, parameters: parameters, encoder: JSONParameterEncoder.default)
        }, options: options, isAsync: true, queue: queue, completion: completion)
    }
    
    // Async version, dictionary as parameter
    @discardableResult
    public static func request<Response: Decodable>(
        method: HTTPMethod,
        path: String,
        parameters: [String: Any]? = nil,
        options: Options = [],
        queue: DispatchQueue = .main
    ) async throws -> Response {
        guard let url = url(with: path) else {
            throw MixinAPIError.invalidPath
        }
        return try await withCheckedThrowingContinuation { continuation in
            request(makeRequest: { (session) -> DataRequest in
                session.request(url, method: method, parameters: parameters, encoding: JSONEncoding.default)
            }, options: options, isAsync: true, queue: queue, completion: { result in
                continuation.resume(with: result)
            })
        }
    }
    
    // Callback version, dictionary as parameter
    @discardableResult
    public static func request<Response>(
        method: HTTPMethod,
        path: String,
        parameters: [String: Any]? = nil,
        options: Options = [],
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
        }, options: options, isAsync: true, queue: queue, completion: completion)
    }
    
    // Blocking version, model as parameter
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
    
    // Blocking version, dictionary as parameter
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
        let error: MixinAPIResponseError?
    }
    
    private static let session: Alamofire.Session = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let tokenInterceptor = AccessTokenInterceptor()
        let redirector = Redirector(behavior: .doNotFollow)
        let session = Alamofire.Session(configuration: config, interceptor: tokenInterceptor, redirectHandler: redirector)
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
        
        let request = Self.request(makeRequest: makeRequest, options: [], isAsync: false) { (theResult: MixinAPI.Result<Response>) in
            result = theResult
            semaphore.signal()
        }
        if request != nil {
            semaphore.wait()
        }
        
        if case let .failure(error) = result, error.isTransportTimedOut {
            Logger.general.error(category: "MixinAPI", message: "Sync request timed out with: \(error), timeout: \(requestTimeout)")
        }
        
        return result
    }
    
    @discardableResult
    private static func request<Response>(
        makeRequest: @escaping (Alamofire.Session) -> DataRequest,
        options: Options,
        isAsync: Bool,
        queue: DispatchQueue = .main,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request? {
        guard options.contains(.authIndependent) || LoginManager.shared.isLoggedIn else {
            return nil
        }
        let requestTime = Date()
        let host = MixinHost.http
        
        func handleDeauthorization(response: HTTPURLResponse?) {
            let xServerTime = TimeInterval(response?.value(forHTTPHeaderField: "x-server-time") ?? "0") ?? 0
            let serverTimeIntervalSince1970 = xServerTime / TimeInterval(NSEC_PER_SEC)
            let serverTime = Date(timeIntervalSince1970: serverTimeIntervalSince1970)
            if abs(requestTime.timeIntervalSinceNow) > secondsPerMinute {
                let info: Logger.UserInfo = [
                    "options": options,
                    "interval": requestTime.timeIntervalSinceNow,
                    "isAsync": isAsync,
                    "url": (response as? HTTPURLResponse)?.url?.path ?? ""
                ]
                Logger.general.info(category: "MixinAPI", message: "Request signing timeout", userInfo: info)
                if !options.contains(.disableRetryOnRequestSigningTimeout) {
                    request(makeRequest: makeRequest, options: options, isAsync: isAsync, completion: completion)
                } else {
                    completion(.failure(.requestSigningTimeout))
                }
            } else if abs(serverTime.timeIntervalSinceNow) > 5 * secondsPerMinute {
                AppGroupUserDefaults.Account.isClockSkewed = true
                DispatchQueue.main.async {
                    WebSocketService.shared.disconnect()
                    NotificationCenter.default.post(name: MixinService.clockSkewDetectedNotification, object: self)
                }
                completion(.failure(.clockSkewDetected))
            } else {
                completion(.failure(.response(.unauthorized)))
                reporter.report(error: MixinServicesError.logout(isAsyncRequest: true))
                LoginManager.shared.logout(reason: "API access unauthorized, request: \(response?.url?.absoluteString ?? "(null)")")
            }
        }
        
        return makeRequest(session)
            .validate(statusCode: 200...299)
            .responseData(queue: queue, completionHandler: { (response) in
                switch response.result {
                case .success(let data):
                    if let requestId = response.request?.value(forHTTPHeaderField: "x-request-id"), !requestId.isEmpty {
                        let responseRequestId = response.response?.value(forHTTPHeaderField: "x-request-id") ?? ""
                        if requestId != responseRequestId {
                            Logger.general.error(category: "MixinAPI", message: "Mismatched request id. Request path: \(response.request?.url?.path), id: \(requestId), responded header: \(response.response?.allHeaderFields)")
                            completion(.failure(.response(.internalServerError)))
                            return
                        }
                    }
                    do {
                        let responseObject = try JSONDecoder.default.decode(ResponseObject<Response>.self, from: data)
                        if let data = responseObject.data {
                            completion(.success(data))
                        } else if case .some(.unauthorized) = responseObject.error {
                            handleDeauthorization(response: response.response)
                        } else if let error = responseObject.error {
                            completion(.failure(.response(error)))
                        } else {
                            completion(.success(try JSONDecoder.default.decode(Response.self, from: data)))
                        }
                    } catch {
                        Logger.general.error(category: "MixinAPI", message: "Failed to decode response: \(error)" )
                        reporter.report(error: error)
                        completion(.failure(.invalidJSON(error)))
                    }
                case let .failure(error):
                    let path = response.request?.url?.path ?? "(null)"
                    let requestId = response.request?.value(forHTTPHeaderField: "x-request-id") ?? "(null)"
                    Logger.general.error(category: "MixinAPI", message: "Request with path: \(path), id: \(requestId), failed with error: \(error)" )
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
                NSURLErrorResourceUnavailable,
                NSURLErrorSecureConnectionFailed,
            ]
            return nsError.domain == NSURLErrorDomain
                && codes.contains(nsError.code)
        } else {
            return false
        }
    }
    
}
