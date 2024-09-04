import Foundation
import MixinServices

struct GlobalMarket: InstanceInitializable {
    
    let marketCap: Decimal
    let marketCapChangePercentage: Decimal
    let volume: Decimal
    let volumeChangePercentage: Decimal
    let dominance: String
    let dominancePercentage: Decimal
    
}

extension GlobalMarket: Codable {
    
    enum CodingKeys: String, CodingKey {
        case marketCap = "market_cap"
        case marketCapChangePercentage = "market_cap_change_percentage"
        case volume = "volume"
        case volumeChangePercentage = "volume_change_percentage"
        case dominance = "dominance"
        case dominancePercentage = "dominance_percentage"
    }
    
}

extension GlobalMarket: LosslessStringConvertible {
    
    init?(_ description: String) {
        if let data = description.data(using: .utf8),
           let market = try? JSONDecoder.default.decode(GlobalMarket.self, from: data)
        {
            self.init(instance: market)
        } else {
            return nil
        }
    }
    
    var description: String {
        if let data = try? JSONEncoder.default.encode(self),
           let string = String(data: data, encoding: .utf8)
        {
            return string
        } else {
            return ""
        }
    }
    
}
