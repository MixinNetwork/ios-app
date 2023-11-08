import Foundation
import Alamofire

public final class SafeAPI: MixinAPI {
    
    static func register(
        publicKey: String,
        signature: String,
        pin: String,
        salt: String
    ) async throws -> Account {
        let body = [
            "public_key": publicKey,
            "signature": signature,
            "pin_base64": pin,
            "salt_base64": salt
        ]
        return try await request(method: .post, path: "/safe/users", parameters: body)
    }
    
    public static func outputs(
        members: String,
        threshold: Int,
        offset: Int?,
        limit: Int = 200,
        state: String? = nil
    ) async throws -> [Output] {
        var path = "/safe/outputs?members=\(members)&threshold=\(threshold)&limit=\(limit)"
        if let offset {
            path.append("&offset=\(offset)")
        }
        if let state {
            path.append("&state=\(state)")
        }
        return try await request(method: .get, path: path)
    }
    
    public static func snapshot(traceID: String) -> MixinAPI.Result<SafeSnapshot> {
        request(method: .get, path: "/safe/snapshots/trace/" + traceID)
    }
    
}

// MARK: - Asset
extension SafeAPI {
    
    public static func assets(ids: Set<String>) async throws -> [Token] {
        try await request(method: .post, path: "/safe/assets/fetch", parameters: ids)
    }
    
    public static func assets(ids: [String]) async throws -> [Token] {
        try await request(method: .post, path: "/safe/assets/fetch", parameters: ids)
    }
    
    public static func assets() async throws -> [Token] {
        try await request(method: .get, path: "/safe/assets")
    }
    
    public static func assets(id: String) async throws -> Token {
        try await request(method: .get, path: "/safe/assets/\(id)")
    }
    
    public static func assets(id: String) -> MixinAPI.Result<Token> {
        request(method: .get, path: "/safe/assets/\(id)")
    }
    
}

// MARK: - Transfer
extension SafeAPI {
    
    public static func ghostKeys(
        receiverID: String,
        receiverHint: String,
        senderID: String,
        senderHint: String
    ) async throws -> [GhostKey] {
        struct Receiver: Encodable {
            let receivers: [String]
            let index: Int
            let hint: String
        }
        let body = [
            Receiver(receivers: [receiverID], index: 0, hint: receiverHint),
            Receiver(receivers: [senderID], index: 1, hint: senderHint),
        ]
        return try await request(method: .post, path: "/safe/keys", parameters: body)
    }
    
    public static func transaction(id: String) async throws -> TransactionResponse {
        try await request(method: .get, path: "/safe/transactions/" + id)
    }
    
    public static func requestTransaction(requests: [TransactionRequest]) async throws -> [RequestTransactionResponse] {
        try await request(method: .post, path: "/safe/transaction/requests", parameters: requests)
    }
    
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
    
    public static func snapshots(
        asset: String?,
        opponent: String?,
        offset: String?,
        limit: Int?
    ) -> MixinAPI.Result<[SafeSnapshot]> {
        var parameters: [String] = []
        if let asset {
            parameters.append("asset=\(asset)")
        }
        if let opponent {
            parameters.append("opponent=\(opponent)")
        }
        if let offset {
            parameters.append("offset=\(offset)")
        }
        if let limit {
            parameters.append("limit=\(limit)")
        }
        var path = "/safe/snapshots"
        if !parameters.isEmpty {
            path.append("?")
            path.append(parameters.joined(separator: "&"))
        }
        return request(method: .get, path: path)
    }
    
}

// MARK: - Deposit
extension SafeAPI {
    
    public static func depositEntries(chainID: String, completion: @escaping (MixinAPI.Result<[DepositEntry]>) -> Void) {
        request(method: .post, path: "/safe/deposit/entries", parameters: ["chain_id": chainID]) { (result: MixinAPI.Result<[DepositEntry]>) in
            switch result {
            case .success(let entries):
                if entries.allSatisfy(\.isSignatureValid) {
                    completion(.success(entries))
                } else {
                    completion(.failure(.invalidSignature))
                }
            case .failure:
                completion(result)
            }
        }
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
