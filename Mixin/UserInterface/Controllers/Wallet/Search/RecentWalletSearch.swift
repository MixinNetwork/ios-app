import Foundation

enum RecentWalletSearch: Codable, Equatable {
    
    case token(assetID: String)
    case earn(productionID: String)
    case collectible(inscriptionHash: String)
    
}
