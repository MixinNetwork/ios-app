import Foundation

public final class FavorableMarket: Market {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case isFavorite = "is_favored"
    }
    
    public var isFavorite: Bool
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        self.isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        try super.init(from: decoder)
    }
    
}
