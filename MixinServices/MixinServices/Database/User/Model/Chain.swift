import Foundation
import GRDB

public struct Chain {
    
    public let chainId: String
    public let name: String
    public let symbol: String
    public let iconUrl: String
    public let threshold: Int
    public let withdrawalMemoPossibility: String
    
    public init(chainId: String, name: String, symbol: String, iconUrl: String, threshold: Int, withdrawalMemoPossibility: String) {
        self.chainId = chainId
        self.name = name
        self.symbol = symbol
        self.iconUrl = iconUrl
        self.threshold = threshold
        self.withdrawalMemoPossibility = withdrawalMemoPossibility
    }
    
}

extension Chain: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case chainId = "chain_id"
        case name
        case symbol
        case iconUrl = "icon_url"
        case threshold
        case withdrawalMemoPossibility = "withdrawal_memo_possibility"
    }
    
}

extension Chain: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "chains"
    
}
