import Foundation

public final class Web3TransactionItem: Web3Transaction {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case tokenSymbol = "token_symbol"
        case tokenUSDPrice = "token_price_usd"
    }
    
    public let tokenSymbol: String?
    public let tokenUSDPrice: String?
    
    public var decimalTokenUSDPrice: Decimal? {
        if let price = tokenUSDPrice {
            Decimal(string: price, locale: .enUSPOSIX)
        } else {
            nil
        }
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        self.tokenSymbol = try container.decodeIfPresent(String.self, forKey: .tokenSymbol)
        self.tokenUSDPrice = try container.decodeIfPresent(String.self, forKey: .tokenUSDPrice)
        try super.init(from: decoder)
    }
    
}
