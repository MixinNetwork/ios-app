import Foundation
import Alamofire

struct SolanaRPCClient {
    
    struct RecentBlockhash {
        let blockhash: String
        let lamportsPerSignature: UInt64
    }
    
    struct ResponseError: Error, Decodable, CustomStringConvertible {
        
        let code: Int
        let message: String
        
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
        
        struct Result: Decodable { }
        
        let response: Response<Result> = try await post(
            method: "getAccountInfo",
            params: [pubkey]
        )
        if let error = response.error {
            throw error
        } else {
            return response.result != nil
        }
    }
    
    func getRecentBlockhash() async throws -> RecentBlockhash {
        
        struct Result: Decodable {
            
            struct Value: Decodable {
                
                struct FeeCalculator: Decodable {
                    let lamportsPerSignature: UInt64
                }
                
                let blockhash: String
                let feeCalculator: FeeCalculator
                
            }
            
            let value: Value
            
        }
        
        let response: Response<Result> = try await post(
            method: "getRecentBlockhash",
            params: [["commitment": "confirmed"]]
        )
        let value = try response.getResult().value
        return RecentBlockhash(blockhash: value.blockhash,
                               lamportsPerSignature: value.feeCalculator.lamportsPerSignature)
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
