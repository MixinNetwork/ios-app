import Foundation
import GRDB

public struct TopAsset: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord, TableRecord, PersistableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case type
        case symbol
        case name
        case iconUrl = "icon_url"
        case balance
        case destination
        case tag
        case priceBtc = "price_btc"
        case priceUsd = "price_usd"
        case changeUsd = "change_usd"
        case chainId = "chain_id"
        case confirmations
        case assetKey = "asset_key"
        case reserve
        case withdrawalMemoPossibility = "withdrawal_memo_possibility"
    }
    
    public static var databaseTableName: String {
        "top_assets"
    }
    
    public let assetId: String
    public let type: String
    public let symbol: String
    public let name: String
    public let iconUrl: String
    public let balance: String
    public let destination: String
    public let tag: String
    public let priceBtc: String
    public let priceUsd: String
    public let changeUsd: String
    public let chainId: String
    public let confirmations: Int
    public let assetKey: String
    public let reserve: String
    public let withdrawalMemoPossibility: String?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assetId = try container.decode(String.self, forKey: .assetId)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl) ?? ""
        balance = try container.decodeIfPresent(String.self, forKey: .balance) ?? ""
        destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? ""
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? ""
        priceBtc = try container.decodeIfPresent(String.self, forKey: .priceBtc) ?? ""
        priceUsd = try container.decodeIfPresent(String.self, forKey: .priceUsd) ?? ""
        changeUsd = try container.decodeIfPresent(String.self, forKey: .changeUsd) ?? ""
        chainId = try container.decodeIfPresent(String.self, forKey: .chainId) ?? ""
        confirmations = try container.decodeIfPresent(Int.self, forKey: .confirmations) ?? 0
        assetKey = try container.decodeIfPresent(String.self, forKey: .assetKey) ?? ""
        reserve = try container.decodeIfPresent(String.self, forKey: .reserve) ?? ""
        withdrawalMemoPossibility = try container.decodeIfPresent(String.self, forKey: .withdrawalMemoPossibility)
    }
    
}
