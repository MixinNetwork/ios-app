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
    
    public static func postTransaction(requestID: String, raw: String) async throws -> TransactionResponse {
        try await request(method: .post,
                          path: "/safe/transactions",
                          parameters: ["request_id": requestID, "raw": raw])
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
    
    public static func assets() async throws -> [Token] {
        try await request(method: .get, path: "/safe/assets")
    }
    
    public static func assets(id: String) async throws -> Token {
        try await request(method: .get, path: "/safe/assets/\(id)")
    }
    
    public static func assets(id: String) -> MixinAPI.Result<Token> {
        request(method: .get, path: "/safe/assets/\(id)")
    }
    
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
    
    public static func deposits(
        assetID: String,
        destination: String,
        tag: String?
    ) async throws -> [SafePendingDeposit] {
        var path = "/safe/deposits?asset=\(assetID)&destination=\(destination)"
        if let tag {
            path.append("&tag=\(tag)")
        }
        return try await request(method: .get, path: path)
    }
    
    public static func transaction(id: String) async throws -> TransactionResponse {
        try await request(method: .get, path: "/safe/transactions/" + id)
    }
    
}
