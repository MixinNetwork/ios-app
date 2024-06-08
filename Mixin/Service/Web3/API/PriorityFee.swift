import Foundation

struct PriorityFee {
    
    let unitPrice: UInt64
    let unitLimit: UInt32
    
}

extension PriorityFee: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case unitPrice = "unit_price"
        case unitLimit = "unit_limit"
    }
    
}
