import Foundation
import Alamofire
import CryptoKit
import MixinServices

final class RouteAPI {
    
    enum SigningError: Error {
        case missingPublicKey
        case missingPrivateKey
        case encodeMessage
        case emptyResponse
        case calculateAgreement
        case combineSealedBox
    }
    
    enum RPCError: Error {
        case invalidResponse
    }
    
}

// MARK: - Swap
extension RouteAPI {
    
    static func swappableTokens(
        source: RouteTokenSource,
        completion: @escaping (MixinAPI.Result<[SwapToken.Codable]>) -> Void
    ) {
        let path = "/web3/tokens?version=\(Bundle.main.shortVersionString)&source=\(source.rawValue)"
        request(method: .get, path: path, completion: completion)
    }
    
    static func stockTokens(
        source: RouteTokenSource,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<[SwapToken.Codable]>) -> Void
    ) {
        let path = "/web3/tokens?version=\(Bundle.main.shortVersionString)&source=\(source.rawValue)&category=stock"
        request(method: .get, path: path, queue: queue, completion: completion)
    }
    
    static func search(
        keyword: String,
        source: RouteTokenSource,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<[SwapToken.Codable]>) -> Void
    ) -> Request? {
        guard let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            completion(.failure(.invalidPath))
            return nil
        }
        let path = "/web3/tokens/search/\(encodedKeyword)?source=\(source.rawValue)"
        return Self.request(method: .get, path: path, queue: queue, completion: completion)
    }
    
    static func quote(
        request: QuoteRequest,
        completion: @escaping (MixinAPI.Result<QuoteResponse>) -> Void
    ) -> Request {
        Self.request(method: .get, path: "/web3/quote?" + request.asParameter(), completion: completion)
    }
    
    static func swap(
        request: SwapRequest,
        completion: @escaping (MixinAPI.Result<SwapResponse>) -> Void
    ) {
        Self.request(method: .post, path: "/web3/swap", with: request, completion: completion)
    }
    
    static func tradeOrders(
        walletID: String,
        limit: Int?,
        offset: String?,
        state: TradeOrder.State? = nil,
    ) async throws -> [TradeOrder] {
        var path = "/web3/swap/orders?walletId=\(walletID)"
        if let limit {
            path.append("&limit=\(limit)")
        }
        if let offset {
            path.append("&offset=\(offset)")
        }
        if let state {
            path.append("&state=\(state.rawValue)")
        }
        return try await request(method: .get, path: path)
    }
    
    static func tradeOrders(
        limit: Int,
        offset: String?,
        walletID: String?,
        state: TradeOrder.State? = nil,
    ) -> MixinAPI.Result<[TradeOrder]> {
        var path = "/web3/swap/orders?limit=\(limit)"
        if let offset {
            path.append("&offset=\(offset)")
        }
        if let walletID {
            path.append("&walletId=\(walletID)")
        }
        if let state {
            path.append("&state=\(state.rawValue)")
        }
        return request(method: .get, path: path)
    }
    
    static func tradeOrders(
        ids: [String],
    ) async throws -> [TradeOrder] {
        try await request(method: .post, path: "/web3/swap/orders", with: ids)
    }
    
    static func swapOrder(
        id: String,
    ) async throws -> TradeOrder {
        try await request(method: .get, path: "/web3/swap/orders/\(id)")
    }
    
    static func limitOrder(
        id: String,
    ) async throws -> TradeOrder {
        try await request(method: .get, path: "/web3/limit_orders/\(id)")
    }
    
    static func createLimitOrder(
        request: MixinLimitOrderRequest,
        completion: @escaping (MixinAPI.Result<MixinLimitOrderResponse>) -> Void
    ) {
        Self.request(method: .post, path: "/web3/limit_orders", with: request, completion: completion)
    }
    
    static func createLimitOrder(
        request: Web3LimitOrderRequest,
        completion: @escaping (MixinAPI.Result<Web3LimitOrderResponse>) -> Void
    ) {
        Self.request(method: .post, path: "/web3/limit_orders", with: request, completion: completion)
    }
    
    static func cancelLimitOrder(
        id: String,
        completion: @escaping (MixinAPI.Result<TradeOrder>) -> Void
    ) {
        request(method: .post, path: "/web3/limit_orders/\(id)/cancel", completion: completion)
    }
    
}

// MARK: - Markets
extension RouteAPI {
    
    static func globalMarket(
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<GlobalMarket>) -> Void
    ) {
        request(method: .get, path: "/markets/globals", queue: queue, completion: completion)
    }
    
    static func markets(
        category: Market.Category,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<[Market]>) -> Void
    ) {
        let path = "/markets?category=\(category.rawValue)&limit=500"
        request(method: .get, path: path, queue: queue, completion: completion)
    }
    
    static func markets(
        id: String,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<Market>) -> Void
    ) {
        request(method: .get, path: "/markets/" + id, queue: queue, completion: completion)
    }
    
    static func markets(
        ids: [String],
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<[Market]>) -> Void
    ) {
        request(method: .post, path: "/markets/fetch", with: ids, queue: queue, completion: completion)
    }
    
    static func markets(
        keyword: String,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<[Market]>) -> Void
    ) {
        request(method: .get, path: "/markets/search/" + keyword, queue: queue, completion: completion)
    }
    
    static func favoriteMarket(
        coinID: String,
        completion: @escaping (MixinAPI.Result<Empty>) -> Void
    ) {
        request(method: .post, path: "/markets/\(coinID)/favorite", completion: completion)
    }
    
    static func unfavoriteMarket(
        coinID: String,
        completion: @escaping (MixinAPI.Result<Empty>) -> Void
    ) {
        request(method: .post, path: "/markets/\(coinID)/unfavorite", completion: completion)
    }
    
    static func priceHistory(
        id: String,
        period: PriceHistoryPeriod,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<PriceHistory>) -> Void
    ) {
        request(
            method: .get,
            path: "/markets/\(id)/price-history?type=\(period.rawValue)",
            queue: queue,
            completion: completion
        )
    }
    
    static func addMarketAlert(
        coinID: String,
        type: MarketAlert.AlertType,
        frequency: MarketAlert.AlertFrequency,
        value: String,
        completion: @escaping (MixinAPI.Result<MarketAlert>) -> Void
    ) {
        let parameters = [
            "coin_id": coinID,
            "type": type.rawValue,
            "frequency": frequency.rawValue,
            "value": value
        ]
        request(
            method: .post,
            path: "/prices/alerts",
            with: parameters,
            completion: completion
        )
    }
    
    static func postAction(
        alertID: String,
        action: MarketAlert.Action,
        completion: @escaping (MixinAPI.Result<Empty>) -> Void
    ) {
        request(
            method: .post,
            path: "/prices/alerts/\(alertID)",
            with: ["action": action.rawValue],
            completion: completion
        )
    }
    
    static func updateMarketAlert(
        alert: MarketAlert,
        completion: @escaping (MixinAPI.Result<MarketAlert>) -> Void
    ) {
        let parameters = [
            "action": "update",
            "type": alert.type.rawValue,
            "frequency": alert.frequency.rawValue,
            "value": alert.value
        ]
        request(
            method: .post,
            path: "/prices/alerts/\(alert.alertID)",
            with: parameters,
            completion: completion
        )
    }
    
    static func marketAlerts(
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<[MarketAlert]>) -> Void
    ) {
        request(
            method: .get,
            path: "/prices/alerts",
            queue: queue,
            completion: completion
        )
    }
    
}

// MARK: - Web3 Wallets
extension RouteAPI {
    
    static func dapps(queue: DispatchQueue, completion: @escaping (MixinAPI.Result<[Web3ChainUpdate]>) -> Void) {
        request(method: .get, path: "/web3/dapps", queue: queue, completion: completion)
    }
    
    static func wallets() async throws -> [CreateWalletResponse] {
        try await request(method: .get, path: "/wallets")
    }
    
    static func createWallet<Request: CreateWalletRequest>(
        _ wallet: Request,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<CreateWalletResponse>) -> Void
    ) {
        request(
            method: .post,
            path: "/wallets",
            with: wallet,
            queue: queue,
            completion: completion
        )
    }
    
    static func createWallet<Request: CreateWalletRequest>(
        _ wallet: Request
    ) async throws -> CreateWalletResponse {
        try await request(method: .post, path: "/wallets", with: wallet)
    }
    
    static func renameWallet(
        id: String,
        name: String,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<Web3Wallet>) -> Void
    ) {
        request(
            method: .post,
            path: "/wallets/\(id)",
            with: ["name": name],
            queue: queue,
            completion: completion
        )
    }
    
    static func renameWallet(id: String, name: String) async throws -> Web3Wallet {
        try await request(
            method: .post,
            path: "/wallets/\(id)",
            with: ["name": name],
        )
    }
    
    static func deleteWallet(
        id: String,
        completion: @escaping (MixinAPI.Result<Empty>) -> Void
    ) {
        request(
            method: .post,
            path: "/wallets/\(id)/delete",
            completion: completion
        )
    }
    
    static func assets(
        walletID: String,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<[Web3Token]>) -> Void
    ) {
        request(
            method: .get,
            path: "/wallets/\(walletID)/assets",
            queue: queue,
            completion: completion
        )
    }
    
    static func assets(
        searchAddresses addresses: [String],
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<[AddressAssets]>) -> Void
    ) {
        request(
            method: .post,
            path: "/assets/search/address",
            with: ["addresses": addresses],
            queue: queue,
            completion: completion
        )
    }
    
    static func asset(assetID: String, address: String) async throws -> Web3Token {
        try await request(method: .get, path: "/assets/\(assetID)?address=\(address)")
    }
    
    static func asset(
        assetID: String,
        address: String,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<Web3Token>) -> Void
    ) {
        request(
            method: .get,
            path: "/assets/\(assetID)?address=\(address)",
            queue: queue,
            completion: completion
        )
    }
    
    static func addresses(walletID: String) -> MixinAPI.Result<[Web3Address]> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: MixinAPI.Result<[Web3Address]> = .failure(.foundNilResult)
        request(method: .get, path: "/wallets/\(walletID)/addresses") { theResult in
            result = theResult
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
    
    static func addresses(walletID: String) async throws -> [Web3Address] {
        try await request(method: .get, path: "/wallets/\(walletID)/addresses")
    }
    
    static func transactions(address: String, offset: String?, limit: Int) -> MixinAPI.Result<[Web3Transaction]> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: MixinAPI.Result<[Web3Transaction]> = .failure(.foundNilResult)
        var path = "/transactions?address=\(address)&limit=\(limit)"
        if let offset {
            path.append("&offset=\(offset)")
        }
        request(method: .get, path: path) { theResult in
            result = theResult
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
    
    static func transaction(chainID: String, hash: String) -> MixinAPI.Result<Web3RawTransaction> {
        request(
            method: .get,
            path: "/web3/transactions/\(hash)?chain_id=\(chainID)"
        )
    }
    
    static func transaction(chainID: String, hash: String) async throws -> Web3RawTransaction {
        try await request(
            method: .get,
            path: "/web3/transactions/\(hash)?chain_id=\(chainID)"
        )
    }
    
    static func simulateEthereumTransaction(
        chainID: String,
        from: String,
        rawTransaction: String
    ) async throws -> TransactionSimulation {
        try await request(
            method: .post,
            path: "/web3/transactions/simulate",
            with: [
                "chain_id": chainID,
                "from": from,
                "raw_transaction": rawTransaction,
            ]
        )
    }
    
    static func simulateSolanaTransaction(
        rawTransaction: String
    ) async throws -> TransactionSimulation {
        try await request(
            method: .post,
            path: "/web3/transactions/simulate",
            with: [
                "chain_id": ChainID.solana,
                "raw_transaction": rawTransaction,
            ]
        )
    }
    
    static func postTransaction(
        chainID: String,
        from: String,
        rawTransaction: String,
        feeType: FeeType?,
    ) async throws -> RichWeb3RawTransaction {
        var parameters = [
            "chain_id": chainID,
            "from": from,
            "raw_transaction": rawTransaction,
        ]
        if let feeType {
            parameters["fee_type"] = feeType.rawValue
        }
        return try await request(
            method: .post,
            path: "/web3/transactions",
            with: parameters
        )
    }
    
    static func userAddressDestination(
        userID: String,
        chainID: String,
        completion: @escaping (MixinAPI.Result<String>) -> Void
    ) {
        struct UserAddressView: Decodable {
            let destination: String
        }
        request(
            method: .get,
            path: "/users/\(userID)/address?chain_id=\(chainID)"
        ) { (result: MixinAPI.Result<UserAddressView>) in
            completion(result.map(\.destination))
        }
    }
    
}

// MARK: - RPC
extension RouteAPI {
    
    struct EthereumFee: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case gasLimit = "gas_limit"
            case maxFeePerGas = "max_fee_per_gas"
            case maxPriorityFeePerGas = "max_priority_fee_per_gas"
        }
        
        let gasLimit: String
        let maxFeePerGas: String
        let maxPriorityFeePerGas: String
        
    }
    
    struct AccountInfo: Decodable {
        let owner: String
    }
    
    static func estimatedEthereumFee(
        mixinChainID: String,
        from: String,
        to: String,
        value: String,
        data: String,
    ) async throws -> EthereumFee {
        try await request(
            method: .post,
            path: "/web3/estimate-fee",
            with: [
                "chain_id": mixinChainID,
                "from": from,
                "to": to,
                "value": value,
                "data": data,
            ]
        )
    }
    
    static func ethereumLatestTransactionCount(
        chainID: String,
        address: String
    ) async throws -> String {
        var hexCount: String = try await request(
            method: .post,
            path: "/web3/rpc?chain_id=\(chainID)",
            with: [
                "method": "eth_getTransactionCount",
                "params": [address, "latest"]
            ]
        )
        if hexCount.hasPrefix("0x") {
            hexCount.removeFirst(2)
        }
        return hexCount
    }
    
    static func solanaPriorityFee(base64Transaction: String) async throws -> PriorityFee {
        try await request(
            method: .post,
            path: "/web3/estimate-fee",
            with: [
                "chain_id": ChainID.solana,
                "raw_transaction": base64Transaction,
            ]
        )
    }
    
    static func solanaLatestBlockhash() async throws -> String {
        
        struct Response: Decodable {
            let blockhash: String
        }
        
        let result: String = try await request(
            method: .post,
            path: "/web3/rpc?chain_id=\(ChainID.solana)",
            with: ["method": "getLatestBlockhash"]
        )
        guard let data = result.data(using: .utf8) else {
            throw RPCError.invalidResponse
        }
        let response = try JSONDecoder.default.decode(Response.self, from: data)
        return response.blockhash
    }
    
    static func solanaAccountExists(pubkey: String) async throws -> Bool {
        let result: String = try await request(
            method: .post,
            path: "/web3/rpc?chain_id=\(ChainID.solana)",
            with: [
                "method": "getAccountInfo",
                "params": [
                    pubkey,
                    ["encoding": "jsonParsed"],
                ],
            ]
        )
        return result != "null"
    }
    
    static func solanaGetAccountInfo(pubkey: String) async throws -> AccountInfo {
        let result: String = try await request(
            method: .post,
            path: "/web3/rpc?chain_id=\(ChainID.solana)",
            with: [
                "method": "getAccountInfo",
                "params": [
                    pubkey,
                    [
                        "commitment": "finalized",
                        "encoding": "jsonParsed",
                    ],
                ],
            ]
        )
        guard let data = result.data(using: .utf8) else {
            throw RPCError.invalidResponse
        }
        return try JSONDecoder.default.decode(AccountInfo.self, from: data)
    }
    
}

// MARK: - Buy
extension RouteAPI {
    
    static func profile() async throws -> RouteProfile {
        try await withCheckedThrowingContinuation { continuation in
            Self.request(method: .get, path: "/profile") { result in
                continuation.resume(with: result)
            }
        }
    }
    
    static func quote(
        currency: String,
        assetID: String,
        completion: @escaping (MixinAPI.Result<RouteQuote>) -> Void
    ) {
        request(
            method: .post,
            path: "/quote",
            with: [
                "currency": currency,
                "asset_id": assetID,
            ],
            completion: completion
        )
    }
    
    static func rampURL(
        amount: String,
        assetID: String,
        currency: String,
        destination: String,
        phoneVerifiedAt: String?,
        phone: String?,
    ) async throws -> URL {
        struct Response: Decodable {
            let url: URL
        }
        var parameters = [
            "amount": amount,
            "asset_id": assetID,
            "currency": currency,
            "destination": destination,
        ]
        if let phoneVerifiedAt {
            parameters["phone_verified_at"] = phoneVerifiedAt
        }
        if let phone {
            parameters["phone"] = phone
        }
        let response: Response = try await request(
            method: .post,
            path: "/ramp/weburl",
            with: parameters
        )
        return response.url
    }
    
}

// MARK: - Signing
extension RouteAPI {
    
    public struct Signature {
        let timestamp: String
        let signature: String
    }
    
    public static func sign(
        appID: String,
        reloadPublicKey: Bool,
        method: String,
        path: String,
        body: Data?
    ) throws -> Signature {
        let appPublicKey: Data
        if !reloadPublicKey, let bpk = AppGroupUserDefaults.appPublicKey[appID] {
            appPublicKey = bpk
        } else {
            switch UserAPI.fetchSessions(userIds: [appID]) {
            case let .failure(error):
                throw error
            case let .success(sessions):
                guard
                    let publicKey = sessions.first?.publicKey,
                    let bpk = Data(base64URLEncoded: publicKey)
                else {
                    throw SigningError.missingPublicKey
                }
                AppGroupUserDefaults.appPublicKey[appID] = bpk
                appPublicKey = bpk
            }
        }
        
        guard let secret = AppGroupKeychain.sessionSecret else {
            throw SigningError.missingPrivateKey
        }
        let privateKey = try Ed25519PrivateKey(rawRepresentation: secret)
        let usk = privateKey.x25519Representation
        guard let keyData = AgreementCalculator.agreement(publicKey: appPublicKey, privateKey: usk) else {
            throw SigningError.calculateAgreement
        }
        
        let timestamp = "\(Int64(Date().timeIntervalSince1970))"
        guard var message = (timestamp + method + path).data(using: .utf8) else {
            throw SigningError.encodeMessage
        }
        if let body {
            message.append(body)
        }
        
        let hash = HMACSHA256.mac(for: message, using: keyData)
        let signature = (myUserId.data(using: .utf8)! + hash).base64RawURLEncodedString()
        
        return Signature(timestamp: timestamp, signature: signature)
    }
    
    private enum Config {
        static let botUserID: String = "61cb8dd4-16b1-4744-ba0c-7b2d2e52fc59"
        static let host: String = "https://api.route.mixin.one"
    }
    
    private final class RouteSigningInterceptor: RequestInterceptor {
        
        private let method: HTTPMethod
        private let path: String
        private let timeoutInterval: TimeInterval?
        
        init(method: HTTPMethod, path: String, timeoutInterval: TimeInterval? = nil) {
            self.method = method
            self.path = path
            self.timeoutInterval = timeoutInterval
        }
        
        func adapt(
            _ urlRequest: URLRequest,
            for session: Alamofire.Session,
            completion: @escaping (Result<URLRequest, Swift.Error>) -> Void
        ) {
            do {
                let signature = try RouteAPI.sign(
                    appID: Config.botUserID,
                    reloadPublicKey: false, // The bot guarantees for not changing the public key
                    method: method.rawValue,
                    path: path,
                    body: urlRequest.httpBody
                )
                var request = urlRequest
                request.setValue(signature.signature, forHTTPHeaderField: "MR-ACCESS-SIGN")
                request.setValue(signature.timestamp, forHTTPHeaderField: "MR-ACCESS-TIMESTAMP")
                request.setValue(MixinAPI.userAgent, forHTTPHeaderField: "User-Agent")
                if let timeoutInterval {
                    request.timeoutInterval = timeoutInterval
                }
                
                completion(.success(request))
            } catch {
                completion(.failure(error))
            }
        }
        
    }
    
}

// MARK: - Implementation
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
    
    public static func request<Response>(
        method: HTTPMethod,
        path: String,
        parameters: [String: Any]? = nil
    ) -> MixinAPI.Result<Response> {
        var result: MixinAPI.Result<Response> = .failure(.foundNilResult)
        
        let semaphore = DispatchSemaphore(value: 0)
        let url = Config.host + path
        let interceptor = RouteSigningInterceptor(method: method, path: path, timeoutInterval: 5)
        let dataRequest = AF.request(
            url,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            interceptor: interceptor
        )
        
        request(dataRequest, queue: .global()) { theResult in
            result = theResult
            semaphore.signal()
        }
        semaphore.wait()
        
        if case let .failure(error) = result, error.isTransportTimedOut {
            Logger.general.error(category: "RouteAPI", message: "Sync request timed out with: \(error), timeout: \(requestTimeout)")
        }
        
        return result
    }
    
    @discardableResult
    private static func request<Parameters: Encodable, Response: Decodable>(
        method: HTTPMethod,
        path: String,
        with parameters: Parameters? = nil
    ) async throws -> Response {
        try await withCheckedThrowingContinuation { continuation in
            request(method: method, path: path, with: parameters) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    @discardableResult
    private static func request<Response: Decodable>(
        method: HTTPMethod,
        path: String,
        with parameters: [String: Any]? = nil
    ) async throws -> Response {
        try await withCheckedThrowingContinuation { continuation in
            request(method: method, path: path, with: parameters) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    @discardableResult
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
                    } else if Response.self == Empty.self {
                        completion(.success(Empty.value as! Response))
                    } else {
                        completion(.failure(.emptyResponse))
                    }
                case .failure(let error):
                    completion(.failure(.httpTransport(error)))
                }
            }
    }
    
}
