import Foundation

struct GaslessTransactionEVMPayload: Codable {
    
    struct UserOperation: Codable {
        let sender: String
        let nonce: String
        let initCode: String
        let callData: String
        let callGasLimit: String
        let verificationGasLimit: String
        let preVerificationGas: String
        let maxFeePerGas: String
        let maxPriorityFeePerGas: String
        let paymasterAndData: String
        let signature: String
    }
    
    struct Signing: Codable {
        
        struct UserOperation: Codable {
            let signType: String
            let message: String
        }
        
        struct EIP7702Auth: Codable {
            
            enum CodingKeys: String, CodingKey {
                case signType, message, address, nonce
                case chainID = "chainId"
            }
            
            let signType: String?
            let message: String?
            let chainID: String?
            let address: String?
            let nonce: String?
            
        }
        
        let userOperation: UserOperation
        let eip7702Auth: EIP7702Auth?
        
    }
    
    let userOperation: UserOperation
    let signing: Signing
    
}
