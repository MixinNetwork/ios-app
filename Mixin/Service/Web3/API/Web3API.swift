import Foundation
import Alamofire
import CryptoKit
import MixinServices

final class Web3API {
    
    enum Error: Swift.Error {
        case missingPublicKey
        case missingPrivateKey
        case encodeMessage
        case calculateAgreement
    }
    
    static func dapps(queue: DispatchQueue, completion: @escaping (MixinAPI.Result<[Web3ChainUpdate]>) -> Void) {
        request(method: .get, path: "/dapps", queue: queue, completion: completion)
    }
    
}

extension Web3API {
    
    private static let host = "https://web3-api.mixin.one"
    
    private static let session: Alamofire.Session = {
        let config: URLSessionConfiguration = .default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let redirector = Redirector(behavior: .doNotFollow)
        let session = Alamofire.Session(configuration: config, redirectHandler: redirector)
        return session
    }()
    
    private static var botPublicKey: Data?
    
    private final class Web3SigningInterceptor: RequestInterceptor {
        
        private let method: HTTPMethod
        private let path: String
        
        init(method: HTTPMethod, path: String) {
            self.method = method
            self.path = path
        }
        
        func adapt(
            _ urlRequest: URLRequest,
            for session: Alamofire.Session,
            completion: @escaping (Result<URLRequest, Swift.Error>) -> Void
        ) {
            do {
                let botPublicKey: Data
                if let bpk = Web3API.botPublicKey {
                    botPublicKey = bpk
                } else {
                    switch UserAPI.fetchSessions(userIds: ["57eff6cd-038b-4ad6-abab-5792f95e05d7"]) {
                    case let .failure(error):
                        throw error
                    case let .success(sessions):
                        guard let publicKey = sessions.first?.publicKey, let bpk = Data(base64URLEncoded: publicKey) else {
                            throw Error.missingPublicKey
                        }
                        Web3API.botPublicKey = bpk
                        botPublicKey = bpk
                    }
                }
                
                guard let secret = AppGroupKeychain.sessionSecret else {
                    throw Error.missingPrivateKey
                }
                let privateKey = try Ed25519PrivateKey(rawRepresentation: secret)
                let usk = privateKey.x25519Representation
                guard let keyData = AgreementCalculator.agreement(publicKey: botPublicKey, privateKey: usk) else {
                    throw Error.calculateAgreement
                }
                
                let timestamp = "\(Int64(Date().timeIntervalSince1970))"
                guard var message = (timestamp + method.rawValue + path).data(using: .utf8) else {
                    throw Error.encodeMessage
                }
                if let body = urlRequest.httpBody {
                    message.append(body)
                }
                
                let hash = HMACSHA256.mac(for: message, using: keyData)
                let signature = (myUserId.data(using: .utf8)! + hash).base64RawURLEncodedString()
                
                var request = urlRequest
                request.setValue(signature, forHTTPHeaderField: "MW-ACCESS-SIGN")
                request.setValue(timestamp, forHTTPHeaderField: "MW-ACCESS-TIMESTAMP")
                request.setValue(MixinAPI.userAgent, forHTTPHeaderField: "User-Agent")
                completion(.success(request))
            } catch {
                completion(.failure(error))
            }
        }
        
    }
    
    private struct ResponseObject<Response: Decodable>: Decodable {
        let data: Response?
        let error: MixinAPIResponseError?
    }
    
    @discardableResult
    private static func request<Parameters: Encodable, Response>(
        method: HTTPMethod,
        path: String,
        with parameters: Parameters? = nil,
        queue: DispatchQueue = .main,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request {
        let interceptor = Web3SigningInterceptor(method: method, path: path)
        let url = Self.host + path
        let dataRequest = session.request(url,
                                          method: method,
                                          parameters: parameters,
                                          encoder: .json,
                                          interceptor: interceptor)
        return request(dataRequest, queue: queue, completion: completion)
    }
    
    private static func request<Response: Decodable>(
        method: HTTPMethod,
        path: String,
        with parameters: [String: Any]? = nil
    ) async throws -> Response {
        let interceptor = Web3SigningInterceptor(method: method, path: path)
        let url = Self.host + path
        let dataRequest = session.request(
            url,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            interceptor: interceptor
        ).serializingDecodable(
            ResponseObject<Response>.self,
            decoder: JSONDecoder.default
        )
        let value = try await dataRequest.value
        if let data = value.data {
            return data
        } else if let error = value.error {
            throw error
        } else {
            throw MixinAPIError.emptyResponse
        }
    }
    
    @discardableResult
    private static func request<Response>(
        method: HTTPMethod,
        path: String,
        with parameters: [String: Any]? = nil,
        queue: DispatchQueue = .main,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request {
        let interceptor = Web3SigningInterceptor(method: method, path: path)
        let url = Self.host + path
        let dataRequest = session.request(url,
                                          method: method,
                                          parameters: parameters,
                                          encoding: JSONEncoding.default,
                                          interceptor: interceptor)
        return request(dataRequest, queue: queue, completion: completion)
    }
    
    private static func request<Response>(
        _ request: DataRequest,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request {
        request.validate(statusCode: 200...299)
            .responseDecodable(of: ResponseObject<Response>.self, queue: queue) { response in
                switch response.result {
                case .success(let response):
                    if let data = response.data {
                        completion(.success(data))
                    } else if let error = response.error {
                        completion(.failure(.response(error)))
                    } else {
                        completion(.failure(.emptyResponse))
                    }
                case .failure(let error):
                    completion(.failure(.httpTransport(error)))
                }
            }
    }
    
}
