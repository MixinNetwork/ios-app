import Foundation
import GRDB

struct Web3TokenExtra {
    
    public let walletID: String
    public let assetID: String
    public let isHidden: Bool
    
}

extension Web3TokenExtra: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    enum CodingKeys: String, CodingKey {
        case walletID = "wallet_id"
        case assetID = "asset_id"
        case isHidden = "hidden"
    }
    
}

extension Web3TokenExtra: TableRecord, PersistableRecord {
    
    static let databaseTableName = "tokens_extra"
    
}
