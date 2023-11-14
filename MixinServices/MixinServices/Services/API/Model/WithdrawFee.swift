import Foundation

public final class WithdrawFee {
    
    public let amount: String
    public let assetID: String
    public let type: String
    
    public private(set) lazy var decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
    
}

extension WithdrawFee: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case amount
        case assetID = "asset_id"
        case type
    }
    
}
