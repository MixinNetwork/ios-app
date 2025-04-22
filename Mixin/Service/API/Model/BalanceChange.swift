import Foundation
import MixinServices

struct BalanceChange: Codable, Token {
    
    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case assetKey = "asset_key"
        case amount = "amount"
        case name = "name"
        case symbol = "symbol"
        case iconURL = "icon"
    }
    
    let assetID: String
    let assetKey: String
    let amount: String
    let name: String
    let symbol: String
    let iconURL: String
    
    init(token: Web3TokenItem, amount: Decimal) {
        self.assetID = token.assetID
        self.assetKey = token.assetKey
        self.amount = TokenAmountFormatter.string(from: amount)
        self.name = token.name
        self.symbol = token.symbol
        self.iconURL = token.iconURL
    }
    
}
