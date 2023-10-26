import Foundation
import Alamofire

public final class SafeAPI: MixinAPI {
    
    public static func register(publicKey: String, signature: String, pin: String) async throws -> Account {
        try await request(method: .post,
                          path: "/safe/users",
                          parameters: ["public_key": publicKey, "signature":  signature, "pin_base64": pin])

    }
    
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
    
    public static func requestTransaction(id: String, raw: String, senderID: String) async throws -> [String] {
        
        struct TransactionRequest: Decodable {
            public let views: [String]
        }
        
        let request: TransactionRequest = try await request(method: .post,
                                                            path: "/safe/transaction/requests",
                                                            parameters: ["request_id": id, "raw": raw])
        return request.views
    }
    
    public static func postTransaction(requestID: String, raw: String, senderID: String) async throws -> Empty {
        try await request(method: .post,
                          path: "/safe/transactions",
                          parameters: ["request_id": requestID, "raw": raw])
    }
    
    public static func outputs(
        members: String,
        threshold: Int,
        offset: String? = nil,
        limit: Int = 200,
        state: String? = nil,
        user: String? = nil
    ) async throws -> [Output] {
        var path = "/safe/outputs?receivers=\(members)&threshold=\(threshold)&limit=\(limit)"
        if let offset {
            path.append("&offset=\(offset)")
        }
        if let state {
            path.append("&state=\(state)")
        }
        if let user {
            path.append("&user=\(user)")
        }
        return try await request(method: .get, path: path)
    }
    
    public static func assets(id: String) async throws -> Token {
        try await request(method: .get, path: "/safe/assets/\(id)")
    }
    
    public static func assets(id: String) -> MixinAPI.Result<Token> {
        request(method: .get, path: "/safe/assets/\(id)")
    }
    
    public static func depositEntries(chainID: String, completion: @escaping (MixinAPI.Result<[DepositEntry]>) -> Void) {
        request(method: .post, path: "/safe/deposit_entries", parameters: ["chain_id": chainID]) { (result: MixinAPI.Result<[DepositEntry]>) in
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
