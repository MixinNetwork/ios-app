import Foundation
import Alamofire

struct SolanaRPCClient {
    
    struct ResponseError: Error, Decodable, CustomStringConvertible {
        
        struct Data: Decodable {
            let logs: [String]
        }
        
        let code: Int
        let message: String
        let data: Data
        
        var description: String {
            "SolanaRPCError: \(code), message: \(message)"
        }
        
    }
    
    struct Response<Result: Decodable>: Decodable {
        
        let result: Result?
        let error: ResponseError?
        
        func getResult() throws -> Result {
            if let error = error {
                throw error
            } else if let result {
                return result
            } else {
                throw APIError.invalidResponse
            }
        }
        
    }
    
    enum APIError: Error {
        case invalidResponse
    }
    
    let url: URL
    
    // `pubkey` should be a base58 encoded string
    func accountExists(pubkey: String) async throws -> Bool {
        
        struct Result: Codable {
            
            struct Value: Codable { }
            
            let value: Value?
            
        }
        
        let response: Response<Result> = try await post(
            method: "getAccountInfo",
            params: [pubkey]
        )
        let value = try response.getResult().value
        return value != nil
    }
    
    func getLatestBlockhash() async throws -> String {
        
        struct Result: Decodable {
            
            struct Value: Decodable {
                let blockhash: String
            }
            
            let value: Value
            
        }
        
        let response: Response<Result> = try await post(
            method: "getLatestBlockhash",
            params: nil
        )
        let value = try response.getResult().value
        return value.blockhash
    }
    
    func sendTransaction(signedTransaction: String) async throws -> String {
        let response: Response<String> = try await post(
            method: "sendTransaction",
            params: [
                signedTransaction,
                ["encoding": "base64"]
            ]
        )
        return try response.getResult()
    }
    
    private func post<Response: Decodable>(
        method: String,
        params: [Any]?
    ) async throws -> Response {
        var parameters: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
        ]
        if let params {
            parameters["params"] = params
        }
        let headers = HTTPHeaders([
            HTTPHeader(name: "Content-Type", value: "application/json")
        ])
        let request = AF.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        ).serializingDecodable(
            Response.self,
            decoder: JSONDecoder.default
        )
        return try await request.value
    }
    
}
