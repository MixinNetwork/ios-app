import Foundation
import MixinServices

struct SignedEVMGaslessTransactionProposal: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case chainID = "chain_id"
        case payload = "payload"
        case userOperationSignature = "user_op_signature"
        case eip7702AuthSignature = "eip7702_auth_signature"
    }
    
    let chainID: String
    let payload: GaslessTransactionEVMPayload
    let userOperationSignature: String
    let eip7702AuthSignature: String?
    
}
