import Foundation
import Alamofire
import Goutils
import UIKit

open class MixinAPI {
    
    public typealias Result<Response: Decodable> = Swift.Result<Response, MixinAPIError>
    
    @discardableResult
    public static func request<Parameters: Encodable, Response>(method: HTTPMethod, path: String, parameters: Parameters, requiresLogin: Bool = true, completion: @escaping (MixinAPI.Result<Response>) -> Void) -> Request? {
        request(makeRequest: { (session) -> DataRequest in
            session.request(url(with: path), method: method, parameters: parameters, encoder: JSONParameterEncoder.default)
        }, requiresLogin: requiresLogin, completion: completion)
    }
    
    @discardableResult
    public static func request<Response>(method: HTTPMethod, path: String, parameters: [String: Any]? = nil, requiresLogin: Bool = true, completion: @escaping (MixinAPI.Result<Response>) -> Void) -> Request? {
        request(makeRequest: { (session) -> DataRequest in
            session.request(url(with: path), method: method, parameters: parameters, encoding: JSONEncoding.default)
        }, requiresLogin: requiresLogin, completion: completion)
    }
    
    @discardableResult
    public static func request<Parameters: Encodable, Response>(method: HTTPMethod, path: String, parameters: Parameters) -> MixinAPI.Result<Response> {
        request(makeRequest: { (session) -> DataRequest in
            session.request(url(with: path), method: method, parameters: parameters, encoder: JSONParameterEncoder.default) { (request) in
                request.timeoutInterval = requestTimeout
            }
        }, debugDescription: path)
    }
    
    @discardableResult
    public static func request<Response>(method: HTTPMethod, path: String, parameters: [String: Any]? = nil) -> MixinAPI.Result<Response> {
        request(makeRequest: { (session) -> DataRequest in
            session.request(url(with: path), method: method, parameters: parameters, encoding: JSONEncoding.default) { (request) in
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
        let config = URLSessionConfiguration.default.copy() as! URLSessionConfiguration
        config.timeoutIntervalForRequest = 10
        let tokenInterceptor = AccessTokenInterceptor()
        let session = Alamofire.Session(configuration: config, interceptor: tokenInterceptor)
        return session
    }()
    
    private static func url(with path: String) -> URL {
        let string = "https://" + MixinHost.http + path
        return URL(string: string)!
    }
    
    private static func request<Response>(makeRequest: @escaping (Alamofire.Session) -> DataRequest, debugDescription: String) -> MixinAPI.Result<Response> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: MixinAPI.Result<Response>!
        
        request(makeRequest: makeRequest) { (theResult: MixinAPI.Result<Response>) in
            result = theResult
            semaphore.signal()
        }
        semaphore.wait()
        
        if case let .failure(error) = result, error.isTransportTimedOut {
            Logger.write(log: "[MixinAPI][SyncRequest]...timeout...requestTimeout:\(requestTimeout)... \(debugDescription)")
        }
        
        return result
    }
    
    @discardableResult
    private static func request<Response>(makeRequest: @escaping (Alamofire.Session) -> DataRequest, requiresLogin: Bool = true, completion: @escaping (MixinAPI.Result<Response>) -> Void) -> Request? {
        if requiresLogin && !LoginManager.shared.isLoggedIn {
            return nil
        }
        let requestTime = Date()
        let host = MixinHost.http
        
        func handleDeauthorization(response: HTTPURLResponse?) {
            let xServerTime = response?.allHeaderFields["x-server-time"] as? String ?? "0"
            let serverTimeIntervalSince1970 = (TimeInterval(xServerTime) ?? 0) / TimeInterval(NSEC_PER_SEC)
            let serverTime = Date(timeIntervalSince1970: serverTimeIntervalSince1970)
            if abs(requestTime.timeIntervalSinceNow) > secondsPerMinute {
                request(makeRequest: makeRequest, requiresLogin: requiresLogin, completion: completion)
            } else if abs(serverTime.timeIntervalSinceNow) > 5 * secondsPerMinute {
                AppGroupUserDefaults.Account.isClockSkewed = true
                DispatchQueue.main.async {
                    WebSocketService.shared.disconnect()
                    NotificationCenter.default.post(name: MixinService.clockSkewDetectedNotification, object: self)
                }
            } else {
                reporter.report(error: MixinServicesError.logout(isAsyncRequest: true))
                LoginManager.shared.logout(from: "AsyncRequest")
            }
        }
        
        return makeRequest(session)
            .validate(statusCode: 200...299)
            .responseData(completionHandler: { (response) in
                switch response.result {
                case .success(let data):
                    do {
                        let responseObject = try JSONDecoder.default.decode(ResponseObject<Response>.self, from: data)
                        if let data = responseObject.data {
                            completion(.success(data))
                        } else if let error = responseObject.error {
                            switch error {
                            case .unauthorized:
                                handleDeauthorization(response: response.response)
                            default:
                                if error.isServerSideError {
                                    MixinHost.toggle(currentHttpHost: host)
                                }
                                completion(.failure(error))
                            }
                        } else {
                            completion(.success(try JSONDecoder.default.decode(Response.self, from: data)))
                        }
                    } catch {
                        Logger.write(error: error, extra: "data decode failed.")
                        completion(.failure(.invalidJSON(error)))
                    }
                case let .failure(error):
                    Logger.write(error: error)
                    
                    let shouldToggleServer: Bool = {
                        guard ReachabilityManger.isReachable else {
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
                    }()
                    
                    if shouldToggleServer {
                        MixinHost.toggle(currentHttpHost: host)
                    }
                    
                    switch error {
                    case let .responseValidationFailed(.unacceptableStatusCode(code)):
                        completion(.failure(.invalidHTTPStatusCode(code)))
                    default:
                        completion(.failure(.httpTransport(error)))
                    }
                }
            })
    }
    
}
