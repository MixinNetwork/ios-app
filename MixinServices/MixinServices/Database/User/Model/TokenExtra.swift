import Foundation
import GRDB

public struct TokenExtra {
    
    public let assetID: String
    public let kernelAssetID: String
    public let isHidden: Bool
    public let balance: String?
    public let updatedAt: String
    
    public init(
        assetID: String, kernelAssetID: String,
        isHidden: Bool, balance: String?, updatedAt: String
    ) {
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
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.assetID = try container.decode(String.self, forKey: .assetID)
        self.kernelAssetID = try container.decode(String.self, forKey: .kernelAssetID)
        self.isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        self.balance = try container.decodeIfPresent(String.self, forKey: .balance)
        self.updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
    
}

extension TokenExtra: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "tokens_extra"
    
}
