import UIKit

public final class PerpetualPositionHistoryItem: PerpetualPositionHistory {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case tokenSymbol = "token_symbol"
        case displaySymbol = "display_symbol"
        case iconURL = "icon_url"
        case priceScale = "price_scale"
    }
    
    public let tokenSymbol: String
    public let displaySymbol: String?
    public let iconURL: URL?
    public let priceFormatStyle: Decimal.FormatStyle.Currency
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        let tokenSymbol = try container.decodeIfPresent(String.self, forKey: .tokenSymbol)
        let displaySymbol = try container.decodeIfPresent(String.self, forKey: .displaySymbol)
        let iconURL = try container.decodeIfPresent(String.self, forKey: .iconURL)
        let priceScale = try container.decodeIfPresent(Int.self, forKey: .priceScale) ?? 2
        
        self.tokenSymbol = tokenSymbol ?? ""
        self.displaySymbol = displaySymbol
        self.iconURL = if let iconURL {
            URL(string: iconURL)
        } else {
            nil
        }
        self.priceFormatStyle = PerpetualMarket.userDisplayPriceFormatStyle(scale: priceScale)
        
        try super.init(from: decoder)
    }
    
}
