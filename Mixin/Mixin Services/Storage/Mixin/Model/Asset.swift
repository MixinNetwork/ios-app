import Foundation
import WCDBSwift

public struct Asset: BaseCodable {

    static var tableName: String = "assets"
    static let topAssetsTableName = "top_assets"
    
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

    public enum CodingKeys: String, CodingTableKey {
        
        public typealias Root = Asset
        
        public static let objectRelationalMapping = TableBinding(CodingKeys.self)
        
        public static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                assetId: ColumnConstraintBinding(isPrimary: true)
            ]
        }
        
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
        
    }
    
}

extension Asset {

    static public func createAsset(asset: AssetItem) -> Asset {
        return Asset(assetId: asset.assetId, type: asset.type, symbol: asset.symbol, name: asset.name, iconUrl: asset.iconUrl, balance: asset.balance, destination: asset.destination, tag: asset.tag, priceBtc: asset.priceBtc, priceUsd: asset.priceUsd, changeUsd: asset.changeUsd, chainId: asset.chainId, confirmations: asset.confirmations, assetKey: asset.assetKey)
    }

}
