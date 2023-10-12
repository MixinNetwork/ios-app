import Foundation

struct BuyingTicker {
    
    let currency: String
    let totalAmount: Decimal
    let purchase: Decimal
    let feeByGateway: Decimal
    let feeByMixin: Decimal
    let feePercent: Decimal
    let assetPrice: Decimal
    let assetAmount: Decimal
    let minimum: Decimal
    let maximum: Decimal
    
    func replacing(price: Decimal, assetAmount: Decimal) -> BuyingTicker {
        BuyingTicker(currency: self.currency,
                     totalAmount: self.totalAmount,
                     purchase: self.purchase,
                     feeByGateway: self.feeByGateway,
                     feeByMixin: self.feeByMixin,
                     feePercent: self.feePercent,
                     assetPrice: assetPrice,
                     assetAmount: assetAmount,
                     minimum: self.minimum,
                     maximum: self.maximum)
    }
    
}

extension BuyingTicker: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case currency
        case totalAmount = "total_amount"
        case purchase
        case feeByGateway = "fee_by_gateway"
        case feeByMixin = "fee_by_mixin"
        case feePercent = "fee_percent"
        case assetPrice = "asset_price"
        case assetAmount = "asset_amount"
        case minimum
        case maximum
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currency = try container.decode(String.self, forKey: .currency)
        totalAmount = try container.decodeDecimalString(forKey: .totalAmount)
        purchase = try container.decodeDecimalString(forKey: .purchase)
        feeByGateway = try container.decodeDecimalString(forKey: .feeByGateway)
        feeByMixin = try container.decodeDecimalString(forKey: .feeByMixin)
        feePercent = try container.decodeDecimalString(forKey: .feePercent)
        assetPrice = try container.decodeDecimalString(forKey: .assetPrice)
        assetAmount = try container.decodeDecimalString(forKey: .assetAmount)
        minimum = try container.decodeDecimalString(forKey: .minimum)
        maximum = try container.decodeDecimalString(forKey: .maximum)
    }
    
}
