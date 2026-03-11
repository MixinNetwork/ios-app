import Foundation

public final class PerpetualPositionItem: PerpetualPosition {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case tokenSymbol = "token_symbol"
        case displaySymbol = "display_symbol"
        case iconURL = "icon_url"
    }
    
    public let tokenSymbol: String
    public let displaySymbol: String?
    public let iconURL: URL?
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        let tokenSymbol = try container.decodeIfPresent(String.self, forKey: .tokenSymbol)
        let displaySymbol = try container.decodeIfPresent(String.self, forKey: .displaySymbol)
        let iconURL = try container.decodeIfPresent(String.self, forKey: .iconURL)
        
        self.tokenSymbol = tokenSymbol ?? ""
        self.displaySymbol = displaySymbol
        self.iconURL = if let iconURL {
            URL(string: iconURL)
        } else {
            nil
        }
        
        try super.init(from: decoder)
    }
    
}
