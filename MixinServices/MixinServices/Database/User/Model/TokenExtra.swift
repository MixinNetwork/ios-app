import Foundation
import GRDB

public struct TokenExtra {
    
    public let assetID: String
    public let kernelAssetID: String
    public let isHidden: Bool?
    public let balance: String?
    public let updatedAt: Date
    
    public init(assetID: String, kernelAssetID: String, isHidden: Bool?, balance: String?, updatedAt: Date) {
        self.assetID = assetID
        self.kernelAssetID = kernelAssetID
        self.isHidden = isHidden
        self.balance = balance
        self.updatedAt = updatedAt
    }
    
}

extension TokenExtra: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case kernelAssetID = "kernel_asset_id"
        case isHidden = "hidden"
        case balance
        case updatedAt = "updated_at"
    }
    
}

extension TokenExtra: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "tokens_extra"
    
}
