import Foundation
import GRDB

public struct Chain {
    
    public let chainId: String
    public let name: String
    public let symbol: String
    public let iconUrl: String
    public let threshold: Int
    
    public init(chainId: String, name: String, symbol: String, iconUrl: String, threshold: Int) {
        self.chainId = chainId
        self.name = name
        self.symbol = symbol
        self.iconUrl = iconUrl
        self.threshold = threshold
    }
    
}

extension Chain: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case chainId = "chain_id"
        case name
        case symbol
        case iconUrl = "icon_url"
        case threshold
    }
    
    public enum JoinQueryCodingKeys: String, CodingKey {
        case chainId
        case name = "chainName"
        case symbol = "chainSymbol"
        case iconUrl = "chainIconUrl"
        case threshold = "chainThreshold"
    }
    
}

extension Chain: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "chains"
    
}
