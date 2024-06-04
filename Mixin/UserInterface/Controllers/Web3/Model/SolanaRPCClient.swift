import Foundation
import Alamofire

struct SolanaRPCClient {
    
    struct RecentBlockhash {
        let blockhash: String
        let lamportsPerSignature: UInt64
    }
    
    let url: URL
    
    // `pubkey` should be a base58 encoded string
    func accountExists(pubkey: String) async throws -> Bool {
        
        struct Response: Decodable {
            
            struct Result: Decodable { }
            
            let result: Result?
            
        }
        
        let response: Response = try await post(
            method: "getAccountInfo",
            params: [pubkey]
        )
        return response.result != nil
    }
    
    func getRecentBlockhash() async throws -> RecentBlockhash {
        
        struct Response: Decodable {
            
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
            
            let result: Result
        }
        
        let response: Response = try await post(
            method: "getRecentBlockhash",
            params: nil
        )
        let value = response.result.value
        return RecentBlockhash(blockhash: value.blockhash,
                               lamportsPerSignature: value.feeCalculator.lamportsPerSignature)
    }
    
    func sendTransaction(signedTransaction: String) async throws -> String {
        
        struct Response: Decodable {
            let result: String
        }
        
        let response: Response = try await post(
            method: "sendTransaction",
            params: [
                signedTransaction,
                ["encoding": "base64"]
            ]
        )
        return response.result
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
