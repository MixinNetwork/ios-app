import Foundation
import MixinServices

struct CreateWalletRequest: Codable {
    
    struct Address: Codable {
        
        enum CodingKeys: String, CodingKey {
            case destination
            case chainID = "chain_id"
            case path
        }
        
        let destination: String
        let chainID: String
        let path: String?
        
    }
    
    let name: String
    let category: Web3Wallet.Category
    let addresses: [Address]
    
}
