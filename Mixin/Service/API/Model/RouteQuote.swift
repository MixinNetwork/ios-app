import Foundation

struct RouteQuote {
    
    let minimum: Decimal
    let maximum: Decimal
    
}

extension RouteQuote: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case minimum
        case maximum
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minimum = try container.decodeStringAsDecimal(forKey: .minimum)
        maximum = try container.decodeStringAsDecimal(forKey: .maximum)
    }
    
}
