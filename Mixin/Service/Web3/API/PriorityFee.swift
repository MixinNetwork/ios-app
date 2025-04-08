import Foundation

struct PriorityFee {
    
    let unitPrice: UInt64
    let unitLimit: UInt32
    
    var decimalCount: Decimal {
        Decimal(unitPrice) * Decimal(unitLimit)
        / Solana.microLamportsPerLamport
        / Solana.lamportsPerSOL
    }
    
}

extension PriorityFee: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case unitPrice = "unit_price"
        case unitLimit = "unit_limit"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let unitPrice = try container.decode(String.self, forKey: .unitPrice)
        let unitLimit = try container.decode(String.self, forKey: .unitLimit)
        guard let price = UInt64(unitPrice) else {
            throw DecodingError.dataCorruptedError(
                forKey: CodingKeys.unitPrice,
                in: container,
                debugDescription: "Invalid number"
            )
        }
        guard let limit = UInt32(unitLimit) else {
            throw DecodingError.dataCorruptedError(
                forKey: CodingKeys.unitLimit,
                in: container,
                debugDescription: "Invalid number"
            )
        }
        self.unitPrice = price
        self.unitLimit = limit
    }
    
}
