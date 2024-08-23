import Foundation
import Alamofire
import CryptoKit
import MixinServices

final class RouteAPI {
    
    enum Error: Swift.Error {
        case missingPublicKey
        case missingPrivateKey
        case encodeMessage
        case emptyResponse
        case calculateAgreement
        case combineSealedBox
    }
    
    private enum Config {
        static let botUserID: String = "61cb8dd4-16b1-4744-ba0c-7b2d2e52fc59"
        static let host: String = "https://api.route.mixin.one"
    }
    
    static func swappableTokens(
        source: RouteTokenSource?,
        completion: @escaping (MixinAPI.Result<[SwappableToken]>) -> Void
    ) {
        var path = "/web3/tokens?version=" + Bundle.main.shortVersionString
        if let source {
            path.append("&source=\(source.rawValue)")
        }
        request(method: .get, path: path, completion: completion)
    }
    
    static func quote(
        request: QuoteRequest,
        completion: @escaping (MixinAPI.Result<QuoteResponse>) -> Void
    ) -> Request {
        Self.request(method: .get, path: "/web3/quote?" + request.asParameter(), completion: completion)
    }
    
    static func swap(request: SwapRequest, completion: @escaping (MixinAPI.Result<SwapResponse>) -> Void) {
        Self.request(method: .post, path: "/web3/swap", with: request, completion: completion)
    }
    
    static func market(assetID: String, completion: @escaping (MixinAPI.Result<TokenMarket>) -> Void) {
        request(method: .get, path: "/markets/" + assetID, completion: completion)
    }
    
    static func priceHistory(
        assetID: String,
        period: PriceHistory.Period,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<TokenPrice>) -> Void
    ) {
        request(
            method: .get,
            path: "/markets/\(assetID)/price-history?type=\(period.rawValue)",
            queue: queue,
            completion: completion
        )
    }
    
}

// Authentication not in used currently
extension RouteAPI {
    
    private static var botPublicKey: Data?
    
    private class RouteSigningInterceptor: RequestInterceptor {
        
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
                if let bpk = RouteAPI.botPublicKey {
                    botPublicKey = bpk
                } else {
                    switch UserAPI.fetchSessions(userIds: [Config.botUserID]) {
                    case let .failure(error):
                        throw error
                    case let .success(sessions):
                        guard let publicKey = sessions.first?.publicKey, let bpk = Data(base64URLEncoded: publicKey) else {
                            throw Error.missingPublicKey
                        }
                        RouteAPI.botPublicKey = bpk
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
                request.setValue(signature, forHTTPHeaderField: "MR-ACCESS-SIGN")
                request.setValue(timestamp, forHTTPHeaderField: "MR-ACCESS-TIMESTAMP")
                request.setValue(MixinAPI.userAgent, forHTTPHeaderField: "User-Agent")
                completion(.success(request))
            } catch {
                completion(.failure(error))
            }
        }
        
    }
    
}

extension RouteAPI {
    
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
        let url = Config.host + path
        let interceptor = RouteSigningInterceptor(method: method, path: path)
        let dataRequest = AF.request(
            url,
            method: method,
            parameters: parameters,
            encoder: .json,
            interceptor: interceptor
        )
        return request(dataRequest, queue: queue, completion: completion)
    }
    
    @discardableResult
    private static func request<Response>(
        method: HTTPMethod,
        path: String,
        with parameters: [String: Any]? = nil,
        queue: DispatchQueue = .main,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request {
        let url = Config.host + path
        let interceptor = RouteSigningInterceptor(method: method, path: path)
        let dataRequest = AF.request(
            url,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            interceptor: interceptor
        )
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
