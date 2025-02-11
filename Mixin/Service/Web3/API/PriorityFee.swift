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
    
}
