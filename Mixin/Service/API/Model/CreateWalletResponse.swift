import Foundation
import MixinServices

struct CreateWalletResponse: Codable {
    
    enum BitcoinAvailability {
        case notInvolved
        case available
        case unavailable
    }
    
    let wallet: Web3Wallet
    let addresses: [Web3Address]
    
    var bitcoinAvailability: BitcoinAvailability {
        switch wallet.category.knownCase {
        case .classic, .importedMnemonic:
            let hasBitcoinAddress = addresses.contains { address in
                address.chainID == ChainID.bitcoin
            }
            return hasBitcoinAddress ? .available : .unavailable
        case .importedPrivateKey, .watchAddress, .none:
            return .notInvolved
        }
    }
    
    init(from decoder: any Decoder) throws {
        self.wallet = try Web3Wallet(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.addresses = try container.decode([Web3Address].self, forKey: .addresses)
    }
    
}
