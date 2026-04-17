import Foundation
import web3

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
            let signType: String
            let message: String
            let chainId: String
            let address: String
            let nonce: String
        }
        
        let userOperation: UserOperation
        let eip7702Auth: EIP7702Auth?
        
    }
    
    let userOperation: UserOperation
    let signing: Signing
    
}

extension EthereumAccountProtocol {
    
    func signGaslessPayload(message: Data) throws -> String {
        guard var signed = try? sign(message: message) else {
            throw EthereumAccountError.signError
        }
        guard var last = signed.popLast() else {
            throw EthereumAccountError.signError
        }
        if last < 27 {
            last += 27
        }
        signed.append(last)
        return signed.web3.hexString
    }
    
}
