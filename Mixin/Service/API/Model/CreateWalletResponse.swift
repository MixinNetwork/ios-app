import Foundation
import MixinServices

struct CreateWalletResponse: Codable {
    
    let wallet: Web3Wallet
    let addresses: [Web3Address]
    
    init(from decoder: any Decoder) throws {
        self.wallet = try Web3Wallet(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.addresses = try container.decode([Web3Address].self, forKey: .addresses)
    }
    
}
