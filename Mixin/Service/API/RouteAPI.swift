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
    
    static func sumsubToken(completion: @escaping (MixinAPI.Result<String>) -> Void) {
        struct Response: Decodable {
            let token: String
        }
        request(method: .get, path: "/kyc/token") { (result: MixinAPI.Result<Response>) in
            completion(result.map(\.token))
        }
    }
    
    static func createInstrument(with token: String, completion: @escaping (MixinAPI.Result<PaymentCard>) -> Void) {
        request(method: .post, path: "/checkout/instruments", with: ["token": token], completion: completion)
    }
    
    static func instruments(completion: @escaping (MixinAPI.Result<[PaymentCard]>) -> Void) -> Request {
        request(method: .get, path: "/checkout/instruments", completion: completion)
    }
    
    static func deleteInstrument(with token: String, completion: @escaping (MixinAPI.Result<Empty>) -> Void) {
        request(method: .delete, path: "/checkout/instruments/" + token, completion: completion)
    }
    
    static func createSession(with request: CreateCheckoutSessionRequest) async throws -> CheckoutSession {
        try await withCheckedThrowingContinuation { continuation in
            Self.request(method: .post, path: "/checkout/sessions", with: request) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func session(with id: String) async throws -> CheckoutSession {
        try await withCheckedThrowingContinuation { continuation in
            Self.request(method: .get, path: "/checkout/sessions/\(id)", with: (nil as Empty?)) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func createToken(withApplePayToken token: String, completion: @escaping (MixinAPI.Result<CheckoutToken>) -> Void) {
        let body = ["token": token, "type": "applepay"]
        request(method: .post, path: "/checkout/tokens", with: body, completion: completion)
    }
    
    static func createPayment(with request: CheckoutPaymentRequest, completion: @escaping (MixinAPI.Result<CheckoutPayment>) -> Void) {
        Self.request(method: .post, path: "/checkout/payments", with: request, completion: completion)
    }
    
    static func createPayment(with request: CheckoutPaymentRequest) async throws -> CheckoutPayment {
        try await withCheckedThrowingContinuation { continuation in
            Self.createPayment(with: request) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func payment(with id: String, completion: @escaping (MixinAPI.Result<CheckoutPayment>) -> Void) {
        Self.request(method: .get, path: "/checkout/payments/\(id)", completion: completion)
    }
    
    static func payment(with id: String) async throws -> CheckoutPayment {
        try await withCheckedThrowingContinuation { continuation in
            payment(with: id) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func profile() async throws -> RouteProfile {
        try await withCheckedThrowingContinuation { continuation in
            Self.request(method: .get, path: "/profile") { result in
                continuation.resume(with: result)
            }
        }
    }
    
    @discardableResult
    static func ticker(
        amount: Int,
        assetID: String,
        currency: String,
        completion: @escaping (MixinAPI.Result<BuyingTicker>) -> Void
    ) -> Request {
        struct Request: Encodable {
            let amount: Int
            let asset_id: String
            let currency: String
        }
        let request = Request(amount: amount, asset_id: assetID, currency: currency)
        return Self.request(method: .post, path: "/checkout/ticker", with: request, completion: completion)
    }
    
    static func ticker(amount: Int, assetID: String, currency: String) async throws -> BuyingTicker {
        try await withCheckedThrowingContinuation { continuation in
            Self.ticker(amount: amount, assetID: assetID, currency: currency) { result in
                continuation.resume(with: result)
            }
        }
    }
    
}

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
                    switch UserAPI.fetchSessions(userIds: [BuyCryptoConfig.botUserID]) {
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
                let signature = (myUserId.data(using: .utf8)! + hash).base64URLEncodedString()
                
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
    
    private struct ResponseObject<Response: Decodable>: Decodable {
        let data: Response?
        let error: MixinAPIError?
    }
    
    @discardableResult
    private static func request<Parameters: Encodable, Response>(
        method: HTTPMethod,
        path: String,
        with parameters: Parameters? = nil,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request {
        let interceptor = RouteSigningInterceptor(method: method, path: path)
        let url = BuyCryptoConfig.host + path
        let dataRequest = AF.request(url, method: method, parameters: parameters, encoder: .json, interceptor: interceptor)
        return request(dataRequest, completion: completion)
    }
    
    @discardableResult
    private static func request<Response>(
        method: HTTPMethod,
        path: String,
        with parameters: [String: Any]? = nil,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request {
        let interceptor = RouteSigningInterceptor(method: method, path: path)
        let url = BuyCryptoConfig.host + path
        let dataRequest = AF.request(url, method: method, parameters: parameters, encoding: JSONEncoding.default, interceptor: interceptor)
        return request(dataRequest, completion: completion)
    }
    
    private static func request<Response>(
        _ request: DataRequest,
        completion: @escaping (MixinAPI.Result<Response>) -> Void
    ) -> Request {
        request.validate(statusCode: 200...299)
            .responseDecodable(of: ResponseObject<Response>.self) { response in
                switch response.result {
                case .success(let response):
                    if let data = response.data {
                        completion(.success(data))
                    } else if let error = response.error {
                        completion(.failure(error))
                    } else {
                        completion(.failure(.emptyResponse))
                    }
                case .failure(let error):
                    completion(.failure(.httpTransport(error)))
                }
            }
    }
    
}
