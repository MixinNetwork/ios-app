import Foundation

struct GaslessFee: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case amount = "amount"
    }
    
    let assetID: String
    let amount: Decimal
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let assetID = try container.decode(String.self, forKey: .assetID)
        let amount = try container.decode(String.self, forKey: .amount)
        guard let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) else {
            throw DecodingError.dataCorruptedError(
                forKey: CodingKeys.amount,
                in: container,
                debugDescription: "Invalid amount"
            )
        }
        self.assetID = assetID
        self.amount = decimalAmount
    }
    
}
