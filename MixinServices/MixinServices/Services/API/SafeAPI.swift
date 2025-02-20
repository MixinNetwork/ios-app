import Foundation
import Alamofire

public final class SafeAPI: MixinAPI {
    
    public static func withRetryingOnServerError(
        maxNumberOfTries: Int,
        execute fn: () async throws -> Void,
        shouldRetry: () async -> Bool
    ) async throws {
        var numberOfTries = 0
        repeat {
            do {
                try await fn()
                return
            } catch {
                numberOfTries += 1
                switch error {
                case MixinAPIResponseError.internalServerError, MixinAPIError.httpTransport(.responseValidationFailed(reason: .unacceptableStatusCode)):
                    if numberOfTries == maxNumberOfTries {
                        throw error
                    } else if await !shouldRetry() {
                        return
                    } else {
                        try await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
                        continue
                    }
                default:
                    throw error
                }
            }
        } while LoginManager.shared.isLoggedIn
        throw MixinAPIError.foundNilResult
    }
    
    static func register(
        publicKey: String,
        signature: String,
        pin: String,
        salt: String,
        masterPublicKey: String,
        masterSignature: String
    ) async throws -> Account {
        let body = [
            "public_key": publicKey,
            "signature": signature,
            "pin_base64": pin,
            "salt_base64": salt,
            "master_public_hex": masterPublicKey,
            "master_signature_hex": masterSignature,
        ]
        return try await request(method: .post, path: "/safe/users", parameters: body)
    }
    
    public static func outputs(
        members: String,
        threshold: Int,
        offset: Int?,
        limit: Int = 200,
        state: String? = nil,
        asset: String? = nil
    ) async throws -> [Output] {
        var path = "/safe/outputs?members=\(members)&threshold=\(threshold)&limit=\(limit)"
        if let offset {
            path.append("&offset=\(offset)")
        }
        if let state {
            path.append("&state=\(state)")
        }
        if let asset {
            path.append("&asset=\(asset)")
        }
        return try await request(method: .get, path: path)
    }
    
    public static func scheme(
        uuid: String,
        completion: @escaping (MixinAPI.Result<SafeScheme>) -> Void
    ) {
        request(method: .get, path: "/schemes/" + uuid, completion: completion)
    }
    
}

// MARK: - Asset
extension SafeAPI {
    
    public static func assets(ids: Set<String>) async throws -> [Token] {
        let tokens: [RawToken] = try await request(method: .post, path: "/safe/assets/fetch", parameters: ids)
        return tokens.map(\.asToken)
    }
    
    public static func assets(ids: [String]) async throws -> [Token] {
        let tokens: [RawToken] = try await request(method: .post, path: "/safe/assets/fetch", parameters: ids)
        return tokens.map(\.asToken)
    }
    
    public static func assets() async throws -> [Token] {
        let tokens: [RawToken] = try await request(method: .get, path: "/safe/assets")
        return tokens.map(\.asToken)
    }
    
    public static func assets(id: String) async throws -> Token {
        let token: RawToken = try await request(method: .get, path: "/safe/assets/\(id)")
        return token.asToken
    }
    
    public static func assets(id: String) -> MixinAPI.Result<Token> {
        let result: MixinAPI.Result<RawToken> = request(method: .get, path: "/safe/assets/\(id)")
        return result.map(\.asToken)
    }
    
    public static func assets<EncodableStringSequence: Sequence<String> & Encodable>(
        ids: EncodableStringSequence
    ) -> MixinAPI.Result<[Token]> {
        let results: MixinAPI.Result<[RawToken]> = request(method: .post, path: "/safe/assets/fetch", parameters: ids)
        return results.map { tokens in
            tokens.map(\.asToken)
        }
    }
    
    public static func asset(
        id: String,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<Token>) -> Void
    ) -> Request? {
        request(method: .get, path: "/safe/assets/\(id)", queue: queue, completion: completion)
    }
    
}

// MARK: - Transfer
extension SafeAPI {
    
    public static func ghostKeys(requests: [GhostKeyRequest]) async throws -> [GhostKey] {
        try await request(method: .post, path: "/safe/keys", parameters: requests)
    }
    
    public static func transaction(id: String) async throws -> TransactionResponse {
        try await request(method: .get, path: "/safe/transactions/" + id)
    }
    
    public static func transactions(ids: [String]) async throws -> [TransactionResponse] {
        try await request(method: .post, path: "/safe/transactions/fetch", parameters: ids)
    }
    
    public static func transaction(id: String) -> MixinAPI.Result<TransactionResponse> {
        request(method: .get, path: "/safe/transactions/" + id)
    }
    
    public static func transaction(id: String, completion: @escaping (MixinAPI.Result<TransactionResponse>) -> Void) {
        request(method: .get, path: "/safe/transactions/" + id, completion: completion)
    }
    
    public static func requestTransaction(requests: [TransactionRequest]) async throws -> [RequestTransactionResponse] {
        try await request(method: .post, path: "/safe/transaction/requests", parameters: requests)
    }
    
    @discardableResult
    public static func postTransaction(requests: [TransactionRequest]) async throws -> [TransactionResponse] {
        try await request(method: .post, path: "/safe/transactions", parameters: requests)
    }
    
}

// MARK: - Snapshot
extension SafeAPI {
    
    public static func snapshot(
        with id: String,
        queue: DispatchQueue = .main,
        completion: @escaping (MixinAPI.Result<SafeSnapshot>) -> Void
    ) {
        request(method: .get, path: "/safe/snapshots/" + id, queue: queue, completion: completion)
    }
    
    public static func snapshots(offset: String?, limit: Int) -> MixinAPI.Result<[SafeSnapshot]> {
        var parameters = ["limit=\(limit)"]
        if let offset {
            parameters.append("offset=\(offset)")
        }
        var path = "/safe/snapshots?"
        path.append(parameters.joined(separator: "&"))
        return request(method: .get, path: path)
    }
    
}

// MARK: - Deposit
extension SafeAPI {
    
    public static func depositEntries(assetID: String?, chainID: String) async throws -> [DepositEntry] {
        var parameters = ["chain_id": chainID]
        if let assetID {
            parameters["asset_id"] = assetID
        }
        let entries: [DepositEntry] = try await request(method: .post, path: "/safe/deposit/entries", parameters: parameters)
        if entries.allSatisfy(\.isSignatureValid) {
            return entries
        } else {
            throw MixinAPIError.invalidSignature
        }
    }
    
    public static func allDeposits(
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<[SafePendingDeposit]>) -> Void
    ) {
        request(method: .get, path: "/safe/deposits", queue: queue, completion: completion)
    }
    
    public static func deposits(
        assetID: String,
        destination: String,
        tag: String?
    ) async throws -> [SafePendingDeposit] {
        var path = "/safe/deposits?asset=\(assetID)&destination=\(destination)"
        if let tag, !tag.isEmpty {
            path.append("&tag=\(tag)")
        }
        return try await request(method: .get, path: path)
    }
    
}

// MARK: - Withdraw
extension SafeAPI {
    
    public static func fees(assetID: String, destination: String) async throws -> [WithdrawFee] {
        try await request(method: .get, path: "/safe/assets/\(assetID)/fees?destination=\(destination)")
    }
    
}

// MARK: - Multisig
extension SafeAPI {
    
    public static func multisigs(
        id: String,
        queue: DispatchQueue,
        completion: @escaping (MixinAPI.Result<SafeMultisigResponse>) -> Void
    ) {
        request(method: .get, path: "/safe/multisigs/" + id, queue: queue, completion: completion)
    }
    
    public static func signMultisigs(id: String, request: TransactionRequest) async throws -> Empty {
        try await Self.request(method: .post, path: "/safe/multisigs/\(id)/sign", parameters: request)
    }
    
    public static func revokeMultisigs(id: String) async throws -> Empty {
        try await request(method: .post, path: "/safe/multisigs/\(id)/revoke")
    }
    
}
