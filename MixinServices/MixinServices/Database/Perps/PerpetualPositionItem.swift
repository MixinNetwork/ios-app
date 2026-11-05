import Foundation

public final class PerpetualPositionItem: PerpetualPosition {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case tokenSymbol = "token_symbol"
        case displaySymbol = "display_symbol"
        case iconURL = "icon_url"
        case priceScale = "price_scale"
        case feeRate = "fee_rate"
    }
    
    public let tokenSymbol: String
    public let displaySymbol: String?
    public let iconURL: URL?
    public let priceFormatStyle: Decimal.FormatStyle.Currency
    public let decimalFeeRate: Decimal?
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        let tokenSymbol = try container.decodeIfPresent(String.self, forKey: .tokenSymbol)
        let displaySymbol = try container.decodeIfPresent(String.self, forKey: .displaySymbol)
        let iconURL = try container.decodeIfPresent(String.self, forKey: .iconURL)
        let priceScale = try container.decodeIfPresent(Int.self, forKey: .priceScale) ?? 2
        let feeRate = try container.decodeIfPresent(String.self, forKey: .feeRate)
        
        self.tokenSymbol = tokenSymbol ?? ""
        self.displaySymbol = displaySymbol
        self.iconURL = if let iconURL {
            URL(string: iconURL)
        } else {
            nil
        }
        self.priceFormatStyle = PerpetualMarket.userDisplayPriceFormatStyle(scale: priceScale)
        self.decimalFeeRate = feeRate.flatMap { Decimal(string: $0, locale: .enUSPOSIX) }
        
        try super.init(from: decoder)
    }
    
    public func estimatedClosingAmounts(
        quantity closingQuantity: Decimal,
        feeRate: Decimal?,
    ) -> (fee: Decimal, receiving: Decimal)? {
        let quantity = Decimal(string: quantity, locale: .enUSPOSIX) ?? 0
        guard quantity > 0, let feeRate else {
            return nil
        }
        let proportion = closingQuantity / quantity
        let fee = closingQuantity * decimalMarkPrice * feeRate
        let margin = Decimal(string: margin, locale: .enUSPOSIX) ?? 0
        let receiving = max((margin + decimalUnrealizedPnL) * proportion - fee, 0)
        return (fee: fee, receiving: receiving)
    }
    
}
