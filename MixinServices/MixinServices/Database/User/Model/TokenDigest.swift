import Foundation

public final class TokenDigest {
    
    public let assetID: String
    public let symbol: String
    public let iconURL: String
    public let usdPrice: String
    public let balance: String
    
    public private(set) lazy var decimalValue: Decimal = {
        let price = Decimal(string: usdPrice, locale: .enUSPOSIX) ?? 0
        let balance = Decimal(string: balance, locale: .enUSPOSIX) ?? 0
        return price * balance
    }()
    
}

extension TokenDigest: Codable {
    
    public enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case symbol
        case iconURL = "icon_url"
        case usdPrice = "price_usd"
        case balance
    }
    
}

extension TokenDigest: MixinFetchableRecord {
    
    public static let databaseTableName = "tokens"
    
}
