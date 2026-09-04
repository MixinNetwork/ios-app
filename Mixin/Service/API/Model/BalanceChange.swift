import Foundation
import MixinServices

struct BalanceChange: Decodable, Token {
    
    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case assetKey = "asset_key"
        case amount = "amount"
        case name = "name"
        case symbol = "symbol"
        case iconURL = "icon"
        case from = "from"
    }
    
    let assetID: String
    let assetKey: String
    let amount: String // Positive for incoming, negative for outgoing
    let name: String
    let symbol: String
    let iconURL: String
    let from: String?
    
    init(token: Web3TokenItem, amount: Decimal, from: String) {
        self.assetID = token.assetID
        self.assetKey = token.assetKey
        self.amount = amount.formatted(
            token.canonicalFormatStyle
                .sign(strategy: amount < 0 ? .always() : .never)
        )
        self.name = token.name
        self.symbol = token.symbol
        self.iconURL = token.iconURL
        self.from = from
    }
    
}
